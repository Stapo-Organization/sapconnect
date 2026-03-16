<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use App\Models\EmailNotification;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $template = EmailNotification::where('event_name', 'stock_transfer_created')->first();
        if ($template) {
            $template->subject_ar = 'طلب تحويل جديد {from_warehouse} - {to_warehouse} رقم التحويل : {doc_num}';
            $template->subject_en = 'New Stock Transfer {from_warehouse} - {to_warehouse} Request #: {doc_num}';
            
            $template->body_ar = '
            <div style="text-align: center; margin-bottom: 25px;">
                <h2 style="color: #2B3A42; margin: 0;">إشعار نظام منتجات SAP</h2>
                <p style="color: #666; font-size: 14px;">يوجد طلب تحويل مخزون جديد بانتظار مراجعتكم</p>
            </div>
            
            <p>مرحباً فريق المستودع،</p>
            <p>نود إعلامكم بأنه تم رصد واستيراد طلب تحويل مخزون جديد من نظام SAP بنجاح وينتظر مراجعتها وتأكيد الكميات.</p>
            
            <div class="highlight-box">
                <p style="margin:5px 0;">📦 <b>رقم مستند التحويل:</b> {doc_num}</p>
                <p style="margin:5px 0;">🏢 <b>المستودع المُرسِل (المصدر):</b> {from_warehouse}</p>
                <p style="margin:5px 0;">🎯 <b>المستودع المُستلِم (الوجهة):</b> {to_warehouse}</p>
            </div>

            <h3 style="margin-top: 30px; color: #2B3A42; border-bottom: 2px solid #fec02f; padding-bottom: 5px; display: inline-block;">تفاصيل المنتجات المحولة</h3>
            {items_table_ar}
            
            <p style="margin-top: 25px;">لضمان سير العمليات اللوجستية وتحديث المخزون في الوقت الفعلي، يرجى التكرم بالدخول إلى لوحة تعقب العمليات لمراجعة وتأكيد استلام هذا التحويل.</p>
            
            <div class="button-container">
                <a href="{link}" class="button button-ar">عرض الطلب الآن عبر النظام</a>
            </div>';

            $template->body_en = '
            <div style="text-align: center; margin-bottom: 25px;">
                <h2 style="color: #2B3A42; margin: 0;">Muntajat SAP System Alert</h2>
                <p style="color: #666; font-size: 14px;">A new stock transfer request is pending your review.</p>
            </div>
            
            <p>Hello Warehouse Team,</p>
            <p>Please be advised that a new stock transfer request has been successfully imported from SAP and requires your attention and quantity confirmation.</p>
            
            <div class="highlight-box">
                <p style="margin:5px 0;">📦 <b>Transfer Document Number:</b> {doc_num}</p>
                <p style="margin:5px 0;">🏢 <b>Source Warehouse:</b> {from_warehouse}</p>
                <p style="margin:5px 0;">🎯 <b>Destination Warehouse:</b> {to_warehouse}</p>
            </div>

            <h3 style="margin-top: 30px; color: #2B3A42; border-bottom: 2px solid #fec02f; padding-bottom: 5px; display: inline-block;">Transferred Products Details</h3>
            {items_table_en}
            
            <p style="margin-top: 25px;">To ensure smooth logistics and real-time inventory updates, please access the Operations Tracker dashboard to review and confirm receipt of this transfer.</p>
            
            <div class="button-container">
                <a href="{link}" class="button button-en">View Transfer Over the System</a>
            </div>';

            $template->save();
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down needed for this data update.
    }
};
