<?php

namespace App\Console\Commands;

use App\Services\ContractAlertService;
use Illuminate\Console\Command;

class CheckContractExpiry extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'supply-chain:check-contracts
                            {--days=30,15,7 : Comma-separated days before expiry to alert}';

    /**
     * The console command description.
     */
    protected $description = 'Check for supplier contracts nearing expiry and send alerts';

    /**
     * Execute the console command.
     */
    public function handle(ContractAlertService $service): int
    {
        $daysOption = $this->option('days');
        $thresholdDays = array_map('intval', explode(',', $daysOption));

        $this->info('Checking for expiring contracts...');
        $this->info('Thresholds: ' . implode(', ', $thresholdDays) . ' days');

        $results = $service->checkExpiringContracts($thresholdDays);

        if (empty($results)) {
            $this->info('No contracts expiring at these thresholds.');
        } else {
            $this->info(count($results) . ' alert(s) sent:');
            foreach ($results as $result) {
                $this->line("  → {$result['supplier_name']} (expires: {$result['end_date']}, {$result['days_remaining']} days)");
            }
        }

        return Command::SUCCESS;
    }
}
