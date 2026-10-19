<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Read-only mirrors of A/R invoice HEADERS for the ShipGo (SHIPGO_LIVE_V1) and
 * Muntajat (PPTC_V5_PROD) SAP companies. Lines + the ZATCA e-invoice are read
 * from SAP when an invoice PDF is printed. Nothing is written to SAP.
 */
return new class extends Migration
{
    private const TABLES = [
        'shipgo_invoices'   => ['shipgo_sync_invoices', 'ShipGo — مزامنة الفواتير من SAP', 'shipgo:sync-invoices'],
        'muntajat_invoices' => ['muntajat_sync_invoices', 'Muntajat — مزامنة الفواتير من SAP', 'muntajat:sync-invoices'],
    ];

    public function up(): void
    {
        foreach (self::TABLES as $name => [$code, $label, $command]) {
            Schema::create($name, function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('doc_entry')->unique();
                $table->string('doc_num')->index();
                $table->string('card_code')->nullable()->index();
                $table->string('card_name')->nullable();
                $table->date('doc_date')->nullable()->index();
                $table->string('doc_time', 10)->nullable();
                $table->date('doc_due_date')->nullable();
                $table->date('tax_date')->nullable();
                $table->decimal('doc_total', 15, 2)->default(0);
                $table->decimal('vat_sum', 15, 2)->default(0);
                $table->decimal('paid_to_date', 15, 2)->default(0);
                $table->string('doc_currency', 8)->default('SAR');
                $table->string('status', 10)->default('open')->index();   // open | closed
                $table->boolean('cancelled')->default(false);
                $table->string('num_at_card')->nullable();
                $table->text('comments')->nullable();
                $table->string('buyer_vat')->nullable();
                $table->boolean('zatca_reported')->default(false);
                $table->dateTime('zatca_reported_at')->nullable();
                $table->date('sap_update_date')->nullable()->index();
                $table->timestamp('synced_at')->nullable();
                $table->timestamps();
            });

            if (Schema::hasTable('automations')) {
                Automation::firstOrCreate(['code' => $code], [
                    'name'               => $label,
                    'command_signature'  => $command,
                    'schedule_frequency' => 'hourly',
                    'is_active'          => true,
                    'notify_sms'         => false,
                ]);
            }
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $name => [$code]) {
            if (Schema::hasTable('automations')) {
                Automation::where('code', $code)->delete();
            }
            Schema::dropIfExists($name);
        }
    }
};
