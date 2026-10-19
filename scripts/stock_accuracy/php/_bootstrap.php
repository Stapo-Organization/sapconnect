<?php
declare(strict_types=1);
// Boots Laravel from a standalone script so we can reuse the project's SAP client.
// GET-only usage. Company DB is always PPTC_V5_PROD.
error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);
$base = getenv('APP_BASE') ?: dirname(__DIR__, 3);
require $base . '/vendor/autoload.php';
$app = require $base . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

function sap_client(int $page = 200): \App\Services\ShipGo\PagedSapClient
{
    $c = new \App\Services\ShipGo\PagedSapClient($page);
    $c->setCompanyDb('PPTC_V5_PROD');
    return $c;
}

function argv_opts(array $argv): array
{
    $o = [];
    foreach (array_slice($argv, 1) as $a) {
        if (preg_match('/^--([a-z0-9_-]+)(?:=(.*))?$/s', $a, $m)) {
            $o[$m[1]] = $m[2] ?? true;
        }
    }
    return $o;
}

function err(string $s): void { fwrite(STDERR, $s . PHP_EOL); }

/** GET with retries/backoff. Returns decoded JSON. */
function sap_get_retry($client, string $resource, array $query, int $tries = 3)
{
    $delay = 3;
    for ($i = 1; ; $i++) {
        try {
            return $client->get($resource, $query);
        } catch (\Throwable $e) {
            $code = method_exists($e, 'getCode') ? (int) $e->getCode() : 0;
            // 400 = bad request (wrong field/filter) → do not retry
            if ($code === 400 || $i >= $tries) { throw $e; }
            err("  retry {$i}/{$tries} after error [{$code}] " . substr($e->getMessage(), 0, 160) . " — sleeping {$delay}s");
            sleep($delay); $delay *= 2;
        }
    }
}
