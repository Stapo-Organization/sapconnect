<?php

namespace App\Console\Commands;

use App\Models\Customer;
use App\Services\SAP\SapClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class SyncCustomers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'sap:sync-customers {--code=} {--full}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Sync Customers (Business Partners) from SAP based on active environment.';

    protected $sap;

    /**
     * Execute the console command.
     */
    public function handle(SapClient $sap)
    {
        $this->sap = $sap;

        // 1. Resolve Automation Context
        $code = $this->option('code');
        $automation = null;

        if ($code) {
            $automation = \App\Models\Automation::where('code', $code)->first();
        }

        $sapDatabase = $automation ? $automation->sap_database : 'PPTC_V5_PROD';

        if ($automation) {
            $automation->update([
                'last_run_at' => now(),
                'last_run_status' => 'running',
            ]);
            // Force SAP Config to match Automation Setting
            $this->sap->setCompanyDb($sapDatabase);
        } else {
            // Fallback to session or config if running manually without automation record
            $activeDb = session('sap_company_db', 'PPTC_V5_PROD');
            $this->sap->setCompanyDb($activeDb);
            $sapDatabase = $activeDb;
        }

        $this->info("Starting Customers Sync for Active Database: $sapDatabase");

        try {
            $page = 1;
            $count = 0;
            $pageSize = 100;
            $skip = 0;

            do {
                $this->info("  Fetching page $page... (Skip: $skip)");

                // Explicit pagination with sorting
                $response = $this->sap->get('BusinessPartners', [
                    '$filter' => "CardType eq 'cCustomer' and U_PortalSync eq 'S'",
                    '$orderby' => 'CardCode',
                    '$select' => 'CardCode,CardName,CardType,Phone1,ContactPerson,VatLiable,FederalTaxID,Cellular,City,County,Country,MailCity,MailCounty,MailCountry,EmailAddress,ShipToDefault,CompanyRegistrationNumber,U_PortalSync,U_IBAN,CreateDate,CreateTime,UpdateDate,UpdateTime',
                    '$top' => $pageSize,
                    '$skip' => $skip
                ]);

                $items = $response['value'] ?? [];

                if (empty($items)) {
                    break;
                }

                $fetchedCount = count($items);
                $this->info("    - Retrieved $fetchedCount records.");

                foreach ($items as $item) {
                    $sapCode = $item['CardCode'];
                    
                    $data = [
                        'card_name' => $item['CardName'] ?? null,
                        'card_type' => $item['CardType'] ?? null,
                        'phone1' => $item['Phone1'] ?? null,
                        'contact_person' => $item['ContactPerson'] ?? null,
                        'vat_liable' => $item['VatLiable'] ?? null,
                        'federal_tax_id' => $item['FederalTaxID'] ?? null,
                        'cellular' => $item['Cellular'] ?? null,
                        'city' => $item['City'] ?? null,
                        'county' => $item['County'] ?? null,
                        'country' => $item['Country'] ?? null,
                        'mail_city' => $item['MailCity'] ?? null,
                        'mail_county' => $item['MailCounty'] ?? null,
                        'mail_country' => $item['MailCountry'] ?? null,
                        'email_address' => $item['EmailAddress'] ?? null,
                        'ship_to_default' => $item['ShipToDefault'] ?? null,
                        'company_registration_number' => $item['CompanyRegistrationNumber'] ?? null,
                        'u_portal_sync' => $item['U_PortalSync'] ?? null,
                        'u_iban' => $item['U_IBAN'] ?? null,
                        'create_date' => isset($item['CreateDate']) ? substr($item['CreateDate'], 0, 10) : null,
                        'create_time' => $item['CreateTime'] ?? null,
                        'update_date' => isset($item['UpdateDate']) ? substr($item['UpdateDate'], 0, 10) : null,
                        'update_time' => $item['UpdateTime'] ?? null,
                    ];

                    Customer::updateOrCreate(
                        ['card_code' => $sapCode],
                        $data
                    );
                    $count++;
                }

                if ($fetchedCount === 0) {
                    break;
                }

                $skip += $fetchedCount;
                $page++;

            } while (true);

            $msg = "Customers Sync Completed. Processed $count records from $sapDatabase.";
            $this->info($msg);

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'success',
                    'message' => $msg,
                ]);
            }

        } catch (\Exception $e) {
            $this->error("Failed to sync hooks: " . $e->getMessage());
            Log::error("Customers Sync Failed [$sapDatabase]: " . $e->getMessage());

            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                \App\Models\AutomationLog::create([
                    'automation_id' => $automation->id,
                    'status' => 'failed',
                    'message' => $e->getMessage(),
                ]);
            }
        }
    }
}
