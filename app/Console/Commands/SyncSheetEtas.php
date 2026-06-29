<?php

namespace App\Console\Commands;

use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\ContainerShipment;
use App\Services\Google\GoogleSheetsClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Writes Traqo ship/arrival dates back into the procurement Google Sheet.
 *
 * The sheet is keyed at PO level: the "Container No" column holds one OR MORE
 * container numbers per row. The column letter is resolved from the header row
 * at runtime (so inserted/moved columns can't silently break the link), falling
 * back to COL_CONTAINER. We parse each row's containers, match them to tracked
 * Traqo shipments,
 * and fill the EXISTING ETD (B) / ETA (C) columns plus two appended Traqo columns
 * (status + last-update). Only matched rows are touched — individual cells are
 * written, never whole columns — so manual data in other rows is never clobbered.
 *
 * Read+write to the user's OWN sheet; this does not write to Traqo.
 */
class SyncSheetEtas extends Command
{
    protected $signature = 'traqo:push-sheet {--dry : Parse & match only, write nothing}';
    protected $description = 'Push Traqo ETD/ETA into the procurement Google Sheet (matched containers only)';

    // Existing columns in the sheet
    private const COL_ETD = 'B';   // ETD  → ship date
    private const COL_ETA = 'C';   // ETA  → arrival date
    // Appended Traqo columns (kept clear of the manual "Order Status" in col E)
    private const COL_STATUS  = 'AL';
    private const COL_UPDATED = 'AM';
    private const COL_ISSUES  = 'AN';   // flags malformed container numbers (Phase 3)
    private const COL_TODO    = 'AO';   // NEW active containers not yet in Traqo
    private const COL_CONTAINER = 'Q';  // "Container No" — fallback if header lookup fails
    private const COL_RECEIVED = 'K';   // "Received Dated" — empty = shipment still active

    // Header labels used to resolve the container column dynamically (EN + AR).
    private const CONTAINER_HEADERS = ['container no', 'رقم الحاوية'];

    public function handle(GoogleSheetsClient $sheets): int
    {
        $id = (string) config('services.google_sheets.spreadsheet_id');
        if (!$sheets->configured() || !$id) {
            $this->error('Google Sheets not configured (credentials / spreadsheet_id).');
            return self::FAILURE;
        }

        $lock = Cache::lock('traqo:push-sheet', 600);
        if (!$lock->get()) {
            $this->warn('Another sheet push is already running — skipping.');
            return self::SUCCESS;
        }

        $automation = Automation::where('command_signature', 'traqo:push-sheet')->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        $written = 0;
        $matchedRows = 0;
        $status = 'success';

        try {
            $props = $sheets->firstSheetProps($id);
            $tab = config('services.google_sheets.tab') ?: ($props['title'] ?? null);
            if (!$tab) {
                throw new \RuntimeException('Could not resolve sheet tab (no access?).');
            }
            // A1 ranges must quote sheet names that contain spaces/hyphens.
            $q = "'" . str_replace("'", "''", $tab) . "'";

            // Ensure the grid is wide enough for the appended Traqo columns
            // (Sheets won't auto-expand the grid on a values write).
            $needCols = $this->colIndex(self::COL_TODO); // 1-based index of furthest column
            if (($props['columns'] ?? 0) < $needCols) {
                $sheets->appendColumns($id, (int) ($props['sheetId'] ?? 0), $needCols - (int) $props['columns']);
            }

            // Traqo lookup: normalized container number → shipment
            $traqo = [];
            foreach (ContainerShipment::all() as $s) {
                $traqo[$this->norm($s->reference_number)] = $s;
            }

            // Resolve the container column from the header row so inserted/moved
            // columns can't silently break the link (Q is only the fallback).
            $containerCol = $this->resolveContainerColumn($sheets, $id, $q);
            $this->line("Container column resolved to: {$containerCol}");

            $rows = $sheets->getValues($id, $q . '!' . $containerCol . '1:' . $containerCol . '2000');
            $received = $sheets->getValues($id, $q . '!' . self::COL_RECEIVED . '1:' . self::COL_RECEIVED . '2000');
            $stamp = now()->format('Y-m-d H:i');
            $data = [
                // headers for the appended columns (English — shared sheet)
                ['range' => "{$q}!" . self::COL_STATUS . '1', 'values' => [['Traqo Status']]],
                ['range' => "{$q}!" . self::COL_UPDATED . '1', 'values' => [['Traqo Last Update']]],
                ['range' => "{$q}!" . self::COL_ISSUES . '1', 'values' => [['Container Issues']]],
                ['range' => "{$q}!" . self::COL_TODO . '1', 'values' => [['Track in Traqo?']]],
            ];

            $issueRows = 0;
            $todoRows = 0;
            foreach ($rows as $idx => $row) {
                if ($idx === 0) {
                    continue; // header
                }
                $rowNum = $idx + 1;
                $cell = $row[0] ?? '';
                if ($cell === '') {
                    continue;
                }

                // (a) matched shipments for this row's containers + untracked ones
                $matched = [];
                $untracked = [];
                foreach ($this->parseContainers($cell) as $cn) {
                    if (isset($traqo[$cn])) {
                        $matched[$cn] = $traqo[$cn];
                    } else {
                        $untracked[] = $cn;
                    }
                }

                // (a2) NEW & ACTIVE candidates: row not yet received (K empty) AND
                // has valid containers not in Traqo → these are what to add to Traqo
                // (≤20/month quota), NOT the whole historical backlog.
                // One container per shipment is enough to track (boxes travel
                // together). Suggest a single representative ONLY when NONE of the
                // row's containers is tracked yet; once any is tracked the row is
                // covered → clear any stale suggestion.
                $isReceived = trim($received[$idx][0] ?? '') !== '';
                if (!$isReceived) {
                    if (empty($matched) && !empty($untracked)) {
                        $rep = $untracked[0];
                        $note = count($untracked) > 1 ? " (1 of " . count($untracked) . ")" : '';
                        $data[] = ['range' => "{$q}!" . self::COL_TODO . $rowNum, 'values' => [['Track: ' . $rep . $note]]];
                        $todoRows++;
                    } else {
                        // already covered (or nothing valid) → clear stale flag
                        $data[] = ['range' => "{$q}!" . self::COL_TODO . $rowNum, 'values' => [['']]];
                    }
                }

                // (b) malformed container numbers in this row (Phase 3 hygiene)
                $malformed = $this->malformedTokens($cell);
                if (!empty($malformed)) {
                    $data[] = ['range' => "{$q}!" . self::COL_ISSUES . $rowNum, 'values' => [['Fix: ' . implode(', ', $malformed)]]];
                    $issueRows++;
                }

                if (empty($matched)) {
                    continue;
                }
                $matchedRows++;

                // ETD = earliest ship date; ETA = latest arrival (row "completes"
                // when the last box lands); status = most-urgent matched state.
                $etds = [];
                $etas = [];
                foreach ($matched as $s) {
                    if ($s->shipDate()) $etds[] = $s->shipDate();
                    if ($s->eta)        $etas[] = $s->eta;
                }
                $etd = $etds ? collect($etds)->min()->format('Y-m-d') : null;
                $eta = $etas ? collect($etas)->max()->format('Y-m-d') : null;
                $statusLabel = $this->rowStatus($matched);

                if ($etd) $data[] = ['range' => "{$q}!" . self::COL_ETD . $rowNum, 'values' => [[$etd]]];
                if ($eta) $data[] = ['range' => "{$q}!" . self::COL_ETA . $rowNum, 'values' => [[$eta]]];
                $data[] = ['range' => "{$q}!" . self::COL_STATUS . $rowNum, 'values' => [[$statusLabel]]];
                $data[] = ['range' => "{$q}!" . self::COL_UPDATED . $rowNum, 'values' => [[$stamp]]];
                $written++;

                $this->line("row {$rowNum}: " . implode(',', array_keys($matched)) . " → ETD {$etd} · ETA {$eta} · {$statusLabel}");
            }

            if ($this->option('dry')) {
                $this->info("DRY RUN — matched rows={$matchedRows}, issue rows={$issueRows}, NEW-to-track rows={$todoRows}. Nothing written.");
                $lock->release();
                if ($automation) $automation->update(['last_run_status' => 'success']);
                return self::SUCCESS;
            }

            $ok = $sheets->batchUpdate($id, $data);
            if (!$ok) {
                throw new \RuntimeException('batchUpdate rejected by Sheets API.');
            }

            $msg = "Sheet push success. matchedRows={$matchedRows} written={$written} issueRows={$issueRows} newToTrack={$todoRows}";
            $this->info($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => $msg]);
            }
        } catch (\Throwable $e) {
            $status = 'failed';
            $msg = 'Sheet push error: ' . $e->getMessage();
            Log::error($msg);
            $this->error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        } finally {
            $lock->release();
        }

        return $status === 'failed' ? self::FAILURE : self::SUCCESS;
    }

    /** Pull valid ISO-6346 container numbers (4 letters + 7 digits) from a cell. */
    private function parseContainers(string $cell): array
    {
        preg_match_all('/[A-Z]{4}\d{7}/', strtoupper(str_replace([' ', "\n", "\r"], ['', ',', ','], $cell)), $m);
        return array_values(array_unique($m[0] ?? []));
    }

    private function norm(?string $cn): string
    {
        return strtoupper(trim((string) $cn));
    }

    /**
     * Tokens that LOOK like container numbers but aren't valid ISO-6346
     * (4 letters + 7 digits). Internal spaces are ignored first — "CMAU 9644626"
     * de-spaces to a valid number, so it is NOT flagged; only genuine errors
     * (wrong digit count like CMAU790486, or 3-letter prefixes like HLD0169020)
     * are returned, with their ORIGINAL text so the user can find/fix them.
     */
    private function malformedTokens(string $cell): array
    {
        $out = [];
        foreach (preg_split('/[,\n\r]+/', $cell) as $raw) {
            $raw = trim($raw);
            if ($raw === '') {
                continue;
            }
            $clean = strtoupper(str_replace(' ', '', $raw));
            if ($clean === '' || preg_match('/^[A-Z]{4}\d{7}$/', $clean)) {
                continue; // valid (spacing ignored)
            }
            // container-ish: 2–5 leading letters then 3–9 digits, wrong shape
            if (preg_match('/^[A-Z]{2,5}\d{3,9}$/', $clean)) {
                $out[$raw] = true;
            }
        }
        return array_keys($out);
    }

    /**
     * Find the "Container No" column by scanning the header row, so the link
     * survives columns being inserted/moved in the sheet. Falls back to the
     * COL_CONTAINER constant if no matching header is found.
     */
    private function resolveContainerColumn(GoogleSheetsClient $sheets, string $id, string $q): string
    {
        try {
            $header = $sheets->getValues($id, $q . '!A1:BZ1')[0] ?? [];
            foreach ($header as $i => $label) {
                $norm = strtolower(trim((string) $label));
                foreach (self::CONTAINER_HEADERS as $needle) {
                    if ($norm !== '' && str_contains($norm, $needle)) {
                        return $this->indexToCol($i + 1); // 0-based → 1-based → letters
                    }
                }
            }
        } catch (\Throwable $e) {
            $this->warn('Container header lookup failed (' . $e->getMessage() . '); using fallback ' . self::COL_CONTAINER);
        }
        return self::COL_CONTAINER;
    }

    /** 1-based index → column letters (1="A", 17="Q", 39="AM"). */
    private function indexToCol(int $n): string
    {
        $s = '';
        while ($n > 0) {
            $n--;
            $s = chr(65 + ($n % 26)) . $s;
            $n = intdiv($n, 26);
        }
        return $s;
    }

    /** Column letters → 1-based index ("A"=1, "AM"=39). */
    private function colIndex(string $col): int
    {
        $n = 0;
        foreach (str_split($col) as $ch) {
            $n = $n * 26 + (ord($ch) - 64);
        }
        return $n;
    }

    /** Most-urgent state across a row's matched shipments → English label (shared sheet). */
    private function rowStatus(array $matched): string
    {
        $rank = ['overdue' => 0, 'arriving' => 1, 'in_transit' => 2, 'delivered' => 3, 'pending' => 4];
        $best = null;
        foreach ($matched as $s) {
            $st = $s->state();
            if ($best === null || ($rank[$st] ?? 9) < ($rank[$best] ?? 9)) {
                $best = $st;
            }
        }
        return [
            'overdue'    => 'Delayed',
            'arriving'   => 'Arriving Soon',
            'in_transit' => 'In Transit',
            'delivered'  => 'Delivered',
            'pending'    => 'Pending',
        ][$best] ?? '—';
    }
}
