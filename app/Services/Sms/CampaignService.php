<?php

namespace App\Services\Sms;

use App\Models\SmsCampaign;
use App\Models\SmsRecipient;
use App\Services\SMS\TaqnyatService;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class CampaignService
{
    protected $smsService;

    public function __construct(TaqnyatService $smsService)
    {
        $this->smsService = $smsService;
    }

    public function parseFile(SmsCampaign $campaign)
    {
        if (!$campaign->file_path || !Storage::exists($campaign->file_path)) {
            return;
        }

        $path = Storage::path($campaign->file_path);
        $extension = pathinfo($path, PATHINFO_EXTENSION);

        $recipients = [];

        if (strtolower($extension) === 'csv' || strtolower($extension) === 'txt') {
            $recipients = $this->parseCsv($path);
        } else {
            // Fallback for Excel if package exists, otherwise throw error or handle
            if (class_exists(\Maatwebsite\Excel\Facades\Excel::class)) {
                $data = \Maatwebsite\Excel\Facades\Excel::toArray(new \stdClass, $path);
                if (count($data) > 0) {
                    $recipients = $this->transformExcelData($data[0]);
                }
            } else {
                throw new \Exception("Excel parsing requires maatwebsite/excel. Please convert to CSV.");
            }
        }

        // Save recipients
        foreach ($recipients as $row) {
            SmsRecipient::create([
                'sms_campaign_id' => $campaign->id,
                'mobile_number' => $row['mobile'],
                'variables' => $row['variables'] ?? [],
                'status' => 'pending',
            ]);
        }

        $campaign->update([
            'total_recipients' => count($recipients),
            'status' => 'processing' // OR 'ready' if we have a separate step
        ]);
    }

    protected function parseCsv($path)
    {
        $rows = array_map('str_getcsv', file($path));
        $header = array_shift($rows);
        $data = [];

        foreach ($rows as $row) {
            if (count($row) !== count($header))
                continue;
            $rowWithKeys = array_combine($header, $row);

            // Assume first column is phone or look for 'phone'/'mobile'
            $mobile = $this->findMobile($rowWithKeys);
            if ($mobile) {
                $data[] = [
                    'mobile' => $mobile,
                    'variables' => $rowWithKeys
                ];
            }
        }
        return $data;
    }

    protected function transformExcelData($rows)
    {
        // First row is header
        $header = array_shift($rows);
        $data = [];

        foreach ($rows as $row) {
            // Combine header with row
            // Note: simple combination, might need robustness
            if (count($row) !== count($header))
                continue;

            // Convert header items to string to avoid array keys issues
            $cleanHeader = array_map('strval', $header);
            $rowWithKeys = array_combine($cleanHeader, $row);

            $mobile = $this->findMobile($rowWithKeys);
            if ($mobile) {
                $data[] = [
                    'mobile' => $mobile,
                    'variables' => $rowWithKeys
                ];
            }
        }
        return $data;
    }

    protected function findMobile($row)
    {
        // simplistic logic: check for keys like 'phone', 'mobile', or first column
        foreach ($row as $key => $value) {
            if (Str::contains(strtolower($key), ['phone', 'mobile', 'jawwal'])) {
                return $value;
            }
        }
        // Fallback: return first value
        return array_values($row)[0] ?? null;
    }

    public function sendTest(SmsCampaign $campaign, $testNumber, array $variables = [])
    {
        $message = $campaign->message_body;

        // If variables provided in test form, use them
        if (!empty($variables)) {
            foreach ($variables as $key => $value) {
                $message = str_replace("{{$key}}", $value, $message);
            }
        }
        // Fallback: If we have recipients, try to use the first one's variables for preview
        elseif ($recipient = $campaign->recipients()->first()) {
            if ($recipient->variables) {
                foreach ($recipient->variables as $key => $value) {
                    $message = str_replace("{{$key}}", $value, $message);
                }
            }
        }

        return $this->smsService->sendSms($testNumber, $message);
    }

    public function sendCampaign(SmsCampaign $campaign)
    {
        // Prevent timeouts
        set_time_limit(0);
        ignore_user_abort(true);

        // Sync counts before starting to ensure accuracy if resuming
        $campaign->update([
            'sent_count' => $campaign->recipients()->where('status', 'sent')->count(),
            'failed_count' => $campaign->recipients()->where('status', 'failed')->count(),
        ]);

        $recipients = $campaign->recipients()->where('status', 'pending')->get();
        // If no pending recipients, check if we should mark as completed
        if ($recipients->isEmpty()) {
            $campaign->update(['status' => 'completed']);
            return;
        }

        $sent = 0;
        $failed = 0;

        foreach ($recipients as $index => $recipient) {
            $msg = $campaign->message_body;
            if ($recipient->variables) {
                foreach ($recipient->variables as $key => $value) {
                    $msg = str_replace("{{$key}}", $value, $msg);
                }
            }

            $success = $this->smsService->sendSms($recipient->mobile_number, $msg);

            if ($success) {
                $recipient->update(['status' => 'sent']);
                $sent++;
            } else {
                $recipient->update(['status' => 'failed']);
                $failed++;
            }

            // Optional: Update campaign every 50 records to show progress if user refreshes
            if (($index + 1) % 50 === 0) {
                $campaign->update([
                    'sent_count' => $campaign->sent_count + $sent,
                    'failed_count' => $campaign->failed_count + $failed,
                ]);
                // Reset accumulators
                $sent = 0;
                $failed = 0;
            }
        }

        // Final update
        $campaign->update([
            'sent_count' => $campaign->recipients()->where('status', 'sent')->count(),
            'failed_count' => $campaign->recipients()->where('status', 'failed')->count(),
            'status' => 'completed'
        ]);
    }
}
