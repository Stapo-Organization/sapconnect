<?php

namespace App\Console\Commands;

use App\Services\Marketing\BundleGenerator;
use Illuminate\Console\Command;

/**
 * Nightly «حزم زوبوكسي» suggester. Concept-only rows: nothing reaches the
 * store until the owner approves in the app (same rule as ad campaigns).
 */
class SuggestBundles extends Command
{
    protected $signature = 'marketing:suggest-bundles
        {--per-template=12 : Max new suggestions per template}
        {--species= : Restrict to one species (cat|dog|bird|small_pet)}
        {--expire-days=14 : Reject suggestions older than this}';

    protected $description = 'Generate channel-safe bundle suggestions from intelligence + live stock';

    public function handle(BundleGenerator $generator): int
    {
        $expired = $generator->expireStale((int) $this->option('expire-days'));

        $result = $generator->generate(
            (int) $this->option('per-template'),
            $this->option('species') ?: null,
        );

        $this->info(sprintf(
            'bundles: created=%d skipped=%d expired=%d [%s]',
            $result['created'],
            $result['skipped'],
            $expired,
            collect($result['by_template'])->map(fn ($n, $t) => "$t=$n")->implode(' '),
        ));

        return self::SUCCESS;
    }
}
