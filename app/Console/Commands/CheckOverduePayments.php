<?php

namespace App\Console\Commands;

use App\Models\PaymentAlert;
use Illuminate\Console\Command;

class CheckOverduePayments extends Command
{
    /**
     * The name and signature of the console command.
     */
    protected $signature = 'supply-chain:check-overdue-payments';

    /**
     * The console command description.
     */
    protected $description = 'Check for overdue payment alerts and update their status';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('Checking for overdue payments...');

        $overdueAlerts = PaymentAlert::where('status', 'pending')
            ->where('due_date', '<', now())
            ->get();

        if ($overdueAlerts->isEmpty()) {
            $this->info('No overdue payments found.');
            return Command::SUCCESS;
        }

        $count = $overdueAlerts->count();
        $totalAmount = $overdueAlerts->sum('due_amount');

        // Update status to overdue
        PaymentAlert::where('status', 'pending')
            ->where('due_date', '<', now())
            ->update(['status' => 'overdue']);

        $this->warn("{$count} payment(s) marked as overdue (Total: " . number_format($totalAmount, 2) . ")");

        foreach ($overdueAlerts as $alert) {
            $this->line("  → Alert #{$alert->id}: PO #{$alert->purchase_order_id}, Amount: " . number_format($alert->due_amount, 2) . ", Due: {$alert->due_date->format('Y-m-d')}");
        }

        return Command::SUCCESS;
    }
}
