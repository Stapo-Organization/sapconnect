<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\AlrajhiTransaction;
use Illuminate\Support\Facades\Http;

class SyncAlrajhi extends Command
{
    protected $signature = 'sap:sync-alrajhi {--code=} {--full}';
    protected $description = 'Sync Alrajhi Transactions from APIMGW';

    public function handle()
    {
        $code = $this->option('code');
        $automation = null;
        if ($code) {
            $automation = Automation::where('code', $code)->first();
        } else {
            // Default code if none provided
            $automation = Automation::where('code', 'sync_alrajhi')->first();
        }

        $sapDatabase = 'PPTC_V5_PROD';

        $this->info("Starting Alrajhi Transactions Sync...");

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running'
            ]);
        }

        try {
            $url = 'https://vaoprd.muntajat.sa/api/AlrajhiBank/GetAlrajhiTransactions';
            $payload = [
                "fetch_filter" => "",
                "data_fields" => "payment_body,check_balance_body,iban,amount,sap_body,card_code,incoming_payment_body,incoming_payment_status,creation_date"
            ];

            $response = Http::post($url, $payload);

            if ($response->successful()) {
                $data = $response->json();
                $count = 0;

                foreach ($data as $item) {
                    $paymentBody = json_decode($item['payment_body'] ?? '{}', true);
                    $sapBody = json_decode($item['sap_body'] ?? '[]', true);

                    $sapData = [];
                    if (is_string($item['sap_body'])) {
                        $parsed = json_decode($item['sap_body'], true);
                        if (isset($parsed['value']) && is_array($parsed['value'])) {
                            $sapData = $parsed['value'][0] ?? [];
                        } elseif (is_array($parsed)) {
                            $sapData = $parsed[0] ?? [];
                        }
                    }

                    // Extract Invoices
                    $incomingBody = json_decode($item['incoming_payment_body'] ?? '[]', true);

                    $findInvoices = function ($data) use (&$findInvoices) {
                        if (!is_array($data)) return [];
                        if (isset($data['DocEntry']) || isset($data['docEntry'])) return [$data];
                        if (isset($data[0]) && (isset($data[0]['DocEntry']) || isset($data[0]['docEntry']))) return $data;
                        foreach ($data as $key => $value) {
                            if (is_array($value)) {
                                $found = $findInvoices($value);
                                if (!empty($found)) return $found;
                            }
                        }
                        return [];
                    };

                    $invoices = $findInvoices($incomingBody);

                    $header = $paymentBody['NotifyCRDRHeader'] ?? [];
                    $body = $paymentBody['NotifyCRDRBody'] ?? [];
                    $msgReference = $header['MsgReference'] ?? null;
                    $creationDate = $header['SenderTimeStamp'] ?? $item['creation_date'] ?? null;

                    if ($creationDate) {
                        try {
                            $creationDate = \Carbon\Carbon::parse($creationDate)->format('Y-m-d H:i:s');
                        } catch (\Exception $e) {}
                    }

                    if (!$msgReference) {
                        $uniqueStr = ($item['creation_date'] ?? '') . ($item['amount'] ?? '') . ($item['iban'] ?? '');
                        $msgReference = md5($uniqueStr);
                    }

                    $uniqueHash = md5(json_encode($item));

                    AlrajhiTransaction::updateOrCreate(
                        [ 'unique_hash' => $uniqueHash ],
                        [
                            'msg_reference' => $msgReference,
                            'creation_date' => $creationDate,
                            'sap_card_code' => $item['card_code'] ?? null,
                            'transfer_customer_name' => $body['orderingCustName'] ?? null,
                            'sap_customer_name' => $sapData['CardName'] ?? null,
                            'amount' => $item['amount'] ?? 0,
                            'customer_iban' => $item['iban'] ?? null,
                            'payment_iban' => $body['collectionAccIBAN'] ?? null,
                            'invoices' => $invoices,
                            'status' => $item['incoming_payment_status'] ?? null,
                            'raw_data' => $item,
                        ]
                    );
                    $count++;
                }

                $msg = "Alrajhi Sync Completed. Imported/Updated $count transactions.";
                $this->info($msg);

                if ($automation) {
                    $automation->update(['last_run_status' => 'success']);
                    AutomationLog::create([
                        'automation_id' => $automation->id,
                        'status' => 'success',
                        'message' => $msg,
                    ]);
                }
            } else {
                throw new \Exception('API returned status: ' . $response->status());
            }
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }
        }
    }
}
