<?php

namespace Tests\Feature;

use App\Filament\Resources\DraftInvoiceImportResource;
use App\Models\DraftInvoiceRun;
use App\Models\User;
use App\Services\SAP\DraftInvoiceImportService;
use App\Services\SAP\SapClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

/**
 * Sales report -> SAP draft invoices, with SAP faked: customer split, returns
 * netted off the sales, discounts, duplicates, blocking errors, idempotent post.
 */
class DraftInvoiceImportTest extends TestCase
{
    use RefreshDatabase;

    private const HEADER = 'Stores,BP Code,WHS Code,Date,SAP Code,Name,Qty,Unit Price,Disc.%,Total after Disc.,Order Number,Warehouse';

    /** @var object{posts: array, gets: array} */
    private object $sap;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');

        $this->sap = new class extends SapClient {
            public array $posts = [];
            public array $gets = [];
            public array $knownItems = ['P1', 'P2', 'P3'];
            public array $knownCards = ['C1', 'C2'];
            private int $next = 500;

            public function __construct()
            {
            }

            public function setCompanyDb(string $db)
            {
            }

            public function get(string $resource, array $queryParams = [])
            {
                $this->gets[] = $resource;
                if (preg_match("/^Items\\('(.+)'\\)$/", $resource, $m)) {
                    if (!in_array($m[1], $this->knownItems, true)) {
                        throw new \RuntimeException("No matching records found (ODBC -2028) for {$m[1]}");
                    }
                    return ['ManageBatchNumbers' => 'tNO', 'InventoryUoMEntry' => 58];
                }
                if (preg_match("/^BusinessPartners\\('(.+)'\\)$/", $resource, $m)) {
                    if (!in_array($m[1], $this->knownCards, true)) {
                        throw new \RuntimeException("No matching records found (ODBC -2028) for {$m[1]}");
                    }
                    return ['CardCode' => $m[1], 'CardName' => "SAP name {$m[1]}"];
                }
                return ['value' => []];
            }

            public function post(string $resource, array $data = [])
            {
                $this->posts[] = $data;
                $n = $this->next++;
                return ['DocEntry' => $n, 'DocNum' => 9000 + $n];
            }

            public function getCompanyDb()
            {
                return 'PPTC_V5_PROD';
            }
        };
        $this->app->instance(SapClient::class, $this->sap);
    }

    private function file(array $lines): string
    {
        $path = storage_path('framework/testing/draft_' . md5(implode("\n", $lines)) . '.csv');
        @mkdir(dirname($path), 0775, true);
        file_put_contents($path, "\xEF\xBB\xBF" . self::HEADER . "\n" . implode("\n", $lines) . "\n");
        return $path;
    }

    private function run_(string $path, bool $post, array $attrs = []): array
    {
        $run = DraftInvoiceRun::create(array_merge([
            'source_file' => basename($path), 'file_hash' => '', 'company_db' => 'PPTC_V5_PROD',
            'mode' => $post ? 'post' : 'dry_run', 'doc_date' => '2026-09-28', 'chunk_size' => 200,
            'expense_code' => 1, 'no_batches' => true, 'status' => 'running',
        ], $attrs));

        return [app(DraftInvoiceImportService::class)->run($run, $path, $post), $run->fresh()];
    }

    private function storesFile(): string
    {
        return $this->file([
            // C1 sells 100 of P1 on order A, returns 10 of it later ("A-R1").
            'Store One,C1,RUH003,2026-09-01,P1,Item one,100,5,0,500,A,RUH',
            'Store One,C1,RUH003,2026-09-02,P2,Item two,4,50,20,160,B,RUH',
            'Store One,C1,RUH003,2026-09-02,P2,Item two,4,50,20,160,B,RUH', // identical line
            'Store One,C1,RUH003,2026-09-05,P1,Item one,-10,5,0,-50,A-R1,RUH',
            'Store Two,C2,RUH003,2026-09-03,P1,Item one,7,6,0,42,C,RUH',
            'Store Two,C2,RUH003,2026-09-03,P3,Item three,2,10,0,20,C,RUH',
            // C2 returns P3 in full: the line disappears from the draft.
            'Store Two,C2,RUH003,2026-09-04,P3,Item three,-2,10,0,-20,C,RUH',
        ]);
    }

    public function test_analysis_splits_customers_nets_returns_and_never_writes_to_sap(): void
    {
        [$t, $run] = $this->run_($this->storesFile(), post: false);

        $this->assertSame([], $this->sap->posts, 'an analysis must never POST to SAP');
        $this->assertSame(2, $t['drafts']);
        $this->assertSame(['C1|RUH003', 'C2|RUH003'], array_keys($t['warehouses']));
        $this->assertSame('Store One', $t['warehouses']['C1|RUH003']['name']);

        $preview = json_decode(Storage::disk('local')->get($run->preview_path), true);
        $c1 = collect($preview)->firstWhere('warehouse', 'C1|RUH003')['payload'];
        $c2 = collect($preview)->firstWhere('warehouse', 'C2|RUH003')['payload'];

        $this->assertSame('C1', $c1['CardCode']);
        $this->assertSame('oInvoices', $c1['DocObjectCode']);
        // 100 sold - 10 returned = 90; the return is not a line of its own.
        $this->assertEquals(90, $c1['DocumentLines'][0]['Quantity']);
        $this->assertSame('RUH003', $c1['DocumentLines'][0]['WarehouseCode']);
        $this->assertSame(58, $c1['DocumentLines'][0]['UoMEntry']);
        // Discount travels as a percentage on the verbatim price; duplicates stay.
        $this->assertEquals(50, $c1['DocumentLines'][1]['UnitPrice']);
        $this->assertEquals(20, $c1['DocumentLines'][1]['DiscountPercent']);
        $this->assertCount(3, $c1['DocumentLines']);
        $this->assertArrayNotHasKey('DiscountPercent', $c1['DocumentLines'][0]);

        // C2's fully returned P3 is gone.
        $this->assertSame(['P1'], array_column($c2['DocumentLines'], 'ItemCode'));

        $this->assertEquals(90 * 5 + 2 * 160 + 7 * 6, $t['net_total']);
        $this->assertSame(2, $t['returns']['lines']);
        $this->assertEquals(12, $t['returns']['qty']);
        $this->assertEquals(70, $t['returns']['value']);
        $this->assertSame(1, $t['duplicates']['extra_lines']);
        $this->assertEquals(160, $t['duplicates']['value']);
        $this->assertSame(0, $t['errors']);
        $this->assertTrue(Storage::disk('local')->exists($t['report_path']));
    }

    public function test_a_return_prefers_its_own_order(): void
    {
        [, $run] = $this->run_($this->file([
            'S,C1,RUH003,2026-09-01,P1,Item one,5,5,0,25,X,RUH',
            'S,C1,RUH003,2026-09-02,P1,Item one,5,4,0,20,Y,RUH',
            'S,C1,RUH003,2026-09-03,P1,Item one,-3,4,0,-12,Y-R1,RUH',
        ]), post: false);

        $lines = json_decode(Storage::disk('local')->get($run->preview_path), true)[0]['payload']['DocumentLines'];
        $this->assertEquals([5, 2], array_column($lines, 'Quantity'));
    }

    public function test_unknown_item_or_customer_blocks_the_upload(): void
    {
        $path = $this->file([
            'S,C1,RUH003,2026-09-01,P1,Item one,5,5,0,25,X,RUH',
            'S,C1,RUH003,2026-09-01,PX,Ghost,1,5,0,5,X,RUH',
            'S,C9,RUH003,2026-09-01,P1,Item one,1,5,0,5,Z,RUH',
        ]);

        [$t] = $this->run_($path, post: false);
        $this->assertSame(2, $t['errors']);

        $this->expectExceptionMessage('blocking error');
        $this->run_($path, post: true);
    }

    public function test_upload_posts_one_draft_per_customer_and_never_twice(): void
    {
        $path = $this->storesFile();

        [$t] = $this->run_($path, post: true);
        $this->assertSame(2, $t['posted']);
        $this->assertSame(['C1', 'C2'], array_column($this->sap->posts, 'CardCode'));
        $this->assertSame([9500], $t['warehouses']['C1|RUH003']['doc_nums']);

        [$again] = $this->run_($path, post: true);
        $this->assertSame(0, $again['posted']);
        $this->assertSame(2, $again['skipped']);
        $this->assertCount(2, $this->sap->posts, 're-running must not create drafts again');
    }

    public function test_a_run_customer_that_contradicts_the_file_is_refused(): void
    {
        $this->expectExceptionMessage('names other customers');
        $this->run_($this->storesFile(), post: false, attrs: ['card_code' => 'C1']);
    }

    public function test_the_admin_screen_and_review_render(): void
    {
        config(['app.env' => 'local']);
        Role::findOrCreate('Super Admin', 'web');
        $admin = User::create(['name' => 'Admin', 'email' => 'admin@example.test', 'password' => bcrypt('secret')]);
        $admin->assignRole('Super Admin');

        [, $run] = $this->run_($this->storesFile(), post: false);

        $this->actingAs($admin)->get('/admin/draft-invoice-imports')->assertOk()->assertSee('رفع تقرير مبيعات');

        $html = view('filament.resources.draft-invoice-import.review', [
            'run' => $run,
            'notes' => DraftInvoiceImportResource::notes($run),
            'logTail' => null,
        ])->render();
        $this->assertStringContainsString('Store One', $html);
        $this->assertStringContainsString('الملف جاهز للرفع', $html);
        $this->assertStringContainsString('A-R1', $html);
    }
}
