<?php

namespace App\Filament\Pages;

use App\Models\BranchGapTransferRequest;
use App\Services\Inventory\BranchGapExport;
use App\Services\Inventory\BranchGapService;
use App\Services\Inventory\TransferRequestWriter;
use App\Support\AdminShell;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Contracts\Support\Htmlable;
use Livewire\Attributes\Url;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * «عجز الفروع» — items that sell well in the showrooms and on ShipGo but are
 * thin at one branch (default: King Fahd RUH010), with what another warehouse
 * (default: An Nasr RUH002) can spare. Selected lines become one SAP inventory
 * transfer request.
 */
class BranchStockGaps extends Page
{
    protected static string $view = 'filament.pages.branch-stock-gaps';

    protected static ?string $slug = 'stock-gaps';

    protected static ?string $navigationIcon = 'heroicon-o-arrows-right-left';

    protected static ?int $navigationSort = 3;

    #[Url]
    public string $target = BranchGapService::DEFAULT_TARGET;

    #[Url]
    public string $source = BranchGapService::DEFAULT_SOURCE;

    #[Url]
    public int $window = 90;

    #[Url]
    public int $cover = 14;

    #[Url]
    public int $keep = 30;

    #[Url]
    public int $share = 10;

    #[Url]
    public int $min = 20;

    /** «الأهم»: all | 50 | 100 | 200 | p80 (the items behind 80% of the loss). */
    #[Url]
    public string $top = 'all';

    #[Url]
    public string $pet = '';

    #[Url]
    public string $dept = '';

    #[Url]
    public string $brand = '';

    #[Url]
    public string $tab = 'all';

    #[Url]
    public string $q = '';

    /** Last request outcome, shown above the table. */
    public ?array $result = null;

    public const LINES_PER_REQUEST = 100;

    public const TARGETS = ['RUH010', 'RUH002', 'RUH004', 'RUH005', 'RUH006', 'RUH007', 'RUH008'];

    public static function canAccess(): bool
    {
        return auth()->check() && auth()->user()->hasAnyRole(['Super Admin', 'Stakeholder']);
    }

    public static function canRequest(): bool
    {
        return auth()->check() && auth()->user()->hasRole('Super Admin');
    }

    public static function getNavigationGroup(): ?string
    {
        return __('Inventory');
    }

    public static function getNavigationLabel(): string
    {
        return AdminShell::t(['عجز الفروع', 'Branch gaps']);
    }

    public function getTitle(): string|Htmlable
    {
        return AdminShell::t(['عجز الفروع', 'Branch gaps']);
    }

    public function getHeading(): string|Htmlable
    {
        return '';
    }

    public function updated(string $name): void
    {
        if ($name === 'target' && $this->source === $this->target) {
            $this->source = $this->target === BranchGapService::DEFAULT_SOURCE ? BranchGapService::DEFAULT_TARGET : BranchGapService::DEFAULT_SOURCE;
        }
        if ($name === 'pet') {
            $this->dept = '';
            $this->brand = '';
        }
        if ($name === 'dept') {
            $this->brand = '';
        }
        if (in_array($name, ['target', 'source'], true)) {
            $this->result = null;
            $this->dispatch('gaps-reset');
        }
    }

    public function setTab(string $tab): void
    {
        $this->tab = in_array($tab, ['all', 'out', 'transfer', 'none'], true) ? $tab : 'all';
    }

    /** @return array<string, mixed> */
    public function board(bool $everything = false): array
    {
        if (! in_array($this->target, self::TARGETS, true)) {
            $this->target = BranchGapService::DEFAULT_TARGET;
        }
        $svc = app(BranchGapService::class);
        if (! array_key_exists($this->source, $svc->sourceOptions($this->target))) {
            $this->source = BranchGapService::DEFAULT_SOURCE;
        }

        $data = $svc->analyse([
            'target' => $this->target, 'source' => $this->source, 'window' => $this->window, 'cover' => $this->cover,
            'keep' => $this->keep, 'online_share' => $this->share, 'min_monthly' => $this->min,
        ]);

        $rows = collect($data['rows']);

        // Narrow by pet → department → brand; each list only offers what is left.
        $data['facets']['pets'] = $rows->flatMap(fn ($r) => $r['pets'])->countBy()->sortDesc()->all();
        if ($this->pet !== '') {
            $rows = $rows->filter(fn ($r) => in_array($this->pet, $r['pets'], true));
        }
        $data['facets']['depts'] = $this->pet === '' ? [] : $rows->flatMap(fn ($r) => $r['depts'])
            ->filter(fn ($d) => str_starts_with($d, $this->pet . ' › '))->countBy()->sortDesc()->all();
        if ($this->dept !== '') {
            $rows = $rows->filter(fn ($r) => in_array($this->dept, $r['depts'], true));
        }
        $data['facets']['brands'] = $rows->pluck('brand')->filter()->countBy()->sortDesc()->all();
        if ($this->brand !== '') {
            $rows = $rows->filter(fn ($r) => $r['brand'] === $this->brand);
        }

        // Rank by what the gap costs (lost + basket), and keep the most important.
        $rows = $rows->sortByDesc(fn ($r) => $r['lost_value'] + $r['halo_value'])->values();
        $loss = max(1, $rows->sum(fn ($r) => $r['lost_value'] + $r['halo_value']));
        $run = 0;
        $rows = $rows->map(function ($r, $i) use (&$run, $loss) {
            $r['rank'] = $i + 1;
            $r['cum_before'] = $run / $loss * 100;
            $run += $r['lost_value'] + $r['halo_value'];
            $r['cum'] = (int) round($run / $loss * 100);

            return $r;
        });
        $rows = match ($this->top) {
            '50', '100', '200' => $rows->take((int) $this->top),
            'p80' => $rows->filter(fn ($r) => $r['cum_before'] < 80),
            default => $rows,
        };
        $data['totals'] = BranchGapService::totals($rows->all());
        $data['top_share'] = (int) round($rows->sum(fn ($r) => $r['lost_value'] + $r['halo_value']) / $loss * 100);

        $data['tabs'] = [
            'all' => $rows->count(),
            'out' => $rows->where('out', true)->count(),
            'transfer' => $rows->where('suggest', '>', 0)->count(),
            'none' => $rows->where('status', 'none')->count(),
        ];
        $rows = match ($this->tab) {
            'out' => $rows->where('out', true),
            'transfer' => $rows->where('suggest', '>', 0),
            'none' => $rows->where('status', 'none'),
            default => $rows,
        };
        if (($q = trim($this->q)) !== '') {
            $rows = $rows->filter(fn ($r) => str_contains(mb_strtolower($r['name'] . ' ' . $r['code'] . ' ' . $r['barcode']), mb_strtolower($q)));
        }
        $data['shown'] = $rows->count();
        $data['rows'] = ($everything ? $rows : $rows->take(400))->values()->all();
        $data['sources'] = $svc->sourceOptions($this->target);
        $data['history'] = BranchGapTransferRequest::with('user:id,name')->latest()->limit(8)->get();

        return $data;
    }

    /**
     * Raise the SAP transfer request for the selected lines.
     *
     * @param  array<int, array{item_code: string, quantity: int}>  $lines
     */
    public function requestTransfer(array $lines, ?string $note = null): void
    {
        abort_unless(self::canRequest(), 403);

        // SAP documents stay readable for the branch: one request per 100 items.
        $docs = [];
        $pcs = 0;
        $count = 0;
        foreach (array_chunk(array_values($lines), self::LINES_PER_REQUEST) as $chunk) {
            try {
                $req = app(TransferRequestWriter::class)->create($this->source, $this->target, $chunk, auth()->user(), $note);
            } catch (\InvalidArgumentException $e) {
                $this->finishRequest($docs);
                Notification::make()->title($e->getMessage())->danger()->persistent()->send();

                return;
            }
            if ($req->status !== BranchGapTransferRequest::STATUS_POSTED) {
                $this->finishRequest($docs);
                $this->result = ['ok' => false, 'docs' => $docs, 'error' => $req->error, 'reference' => $req->reference];
                Notification::make()->title(AdminShell::t(['ساب رفض الطلب', 'SAP refused the request']))->body($req->error)->danger()->persistent()->send();

                return;
            }
            $docs[] = $req->doc_num;
            $pcs += $req->total_quantity;
            $count += count($req->lines);
        }

        $this->finishRequest($docs);
        $this->result = ['ok' => true, 'docs' => $docs, 'lines' => $count, 'pcs' => $pcs];
        Notification::make()->title(AdminShell::t(['تم إنشاء طلب التحويل في ساب', 'Transfer request created in SAP']) . ' ' . collect($docs)->map(fn ($d) => '#' . $d)->join('، '))->success()->send();
    }

    /** Whatever reached SAP now counts as on the way, and the selection clears. */
    private function finishRequest(array $docs): void
    {
        if ($docs) {
            app(BranchGapService::class)->forget();
            $this->dispatch('gaps-requested');
        }
    }

    public function refreshBoard(): void
    {
        app(BranchGapService::class)->forget();
    }

    /** Excel of exactly what the filters show (every row, not the first 400). */
    public function export(): BinaryFileResponse
    {
        $b = $this->board(everything: true);
        $path = BranchGapExport::write($b, [
            'target' => $this->target, 'source' => $this->source, 'top' => $this->top, 'pet' => $this->pet,
            'dept' => $this->dept, 'brand' => $this->brand, 'tab' => $this->tab, 'q' => $this->q,
        ]);
        $name = 'عجز_' . $this->target . '_من_' . $this->source . '_' . now()->format('Y-m-d_H-i') . '.xlsx';

        return response()->download($path, $name)->deleteFileAfterSend();
    }
}
