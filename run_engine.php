<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "Starting CalculateStockOpportunitiesJob...\n";
\App\Jobs\CalculateStockOpportunitiesJob::dispatchSync(app(\App\Services\SAP\SapClient::class));
echo "Job finished successfully.\n";
