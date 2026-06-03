<?php

namespace App\Console\Commands;

use App\Services\Quality\QualityTaskGenerationService;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;

class GenerateQualityTasksCommand extends Command
{
    protected $signature = 'quality:generate-tasks {--date= : Generate for a specific date (Y-m-d)}';
    protected $description = 'Generate due quality-task instances for all active tasks (idempotent)';

    public function handle(): int
    {
        $date = $this->option('date') ? Carbon::parse($this->option('date')) : now();
        $count = (new QualityTaskGenerationService())->generateDueInstances($date);
        $this->info("✅ Generated {$count} quality-task instance(s) for {$date->toDateString()}.");
        return self::SUCCESS;
    }
}
