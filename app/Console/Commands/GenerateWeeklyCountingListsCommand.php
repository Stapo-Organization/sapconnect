<?php

namespace App\Console\Commands;

use App\Services\Counting\WeeklyCountingListService;
use Illuminate\Console\Command;

class GenerateWeeklyCountingListsCommand extends Command
{
    protected $signature = 'counting:generate-weekly-lists
                            {--force : Force generation even if not due}';

    protected $description = 'Generate weekly counting lists for all active cycle plans that are due today';

    public function handle(): int
    {
        $service = new WeeklyCountingListService();

        $this->info('🔄 Checking active cycle plans for weekly list generation...');

        $generated = $service->processAllPlans();

        if ($generated > 0) {
            $this->info("✅ Generated {$generated} weekly counting list(s).");
        } else {
            $this->info('ℹ️  No lists generated — no plans due today.');
        }

        return Command::SUCCESS;
    }
}
