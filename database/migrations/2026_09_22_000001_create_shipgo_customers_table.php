<?php

use App\Models\Automation;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Local read-only mirror of the customers (Business Partners, CardType =
 * cCustomer) of the ShipGo SAP company (SHIPGO_LIVE_V1). Filled by
 * `shipgo:sync-customers`; nothing here is ever written back to SAP.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipgo_customers', function (Blueprint $table) {
            $table->id();
            $table->string('card_code')->unique();
            $table->string('card_name')->nullable();
            $table->string('card_foreign_name')->nullable();
            $table->integer('group_code')->nullable();
            $table->string('currency', 8)->nullable();
            $table->string('phone1')->nullable();
            $table->string('cellular')->nullable();
            $table->string('email_address')->nullable();
            $table->string('contact_person')->nullable();
            $table->string('city')->nullable();
            $table->string('country', 8)->nullable();
            $table->text('address')->nullable();
            $table->string('federal_tax_id')->nullable();
            $table->integer('pay_terms_grp_code')->nullable();
            $table->decimal('credit_limit', 15, 2)->default(0);
            $table->decimal('current_account_balance', 15, 2)->default(0);
            $table->decimal('open_orders_balance', 15, 2)->default(0);
            $table->decimal('open_delivery_notes_balance', 15, 2)->default(0);
            $table->boolean('valid')->default(true);
            $table->boolean('frozen')->default(false);
            $table->date('sap_create_date')->nullable();
            $table->date('sap_update_date')->nullable();
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();

            $table->index('card_name');
            $table->index('current_account_balance');
        });

        if (Schema::hasTable('automations')) {
            Automation::firstOrCreate(
                ['code' => 'shipgo_sync_customers'],
                [
                    'name'               => 'ShipGo — مزامنة العملاء من SAP',
                    'command_signature'  => 'shipgo:sync-customers',
                    'schedule_frequency' => 'daily',
                    'is_active'          => true,
                    'notify_sms'         => false,
                ]
            );
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('automations')) {
            Automation::where('code', 'shipgo_sync_customers')->delete();
        }
        Schema::dropIfExists('shipgo_customers');
    }
};
