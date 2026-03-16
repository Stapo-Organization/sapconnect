<?php
require __DIR__ . '/bootstrap/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$template = \App\Models\EmailNotification::where("event_name", "stock_transfer_created")->first();
if ($template) {
    $template->subject_ar = "تحديث هام: طلبات تحويل مخزون جديدة ({count}) من {from_warehouse}";
    $template->subject_en = "Important Update: New Stock Transfers ({count}) from {from_warehouse}";
    
    $template->body_ar = "
    <div style=\"text-align: center; margin-bottom: 25px;\">
        <h2 style=\"color: #2B3A42; margin: 0;\">إشعار نظام منتجات SAP</h2>
        <p style=\"color: #666; font-size: 14px;\">يوجد طلبات تحويل مخزون جديدة بانتظار مراجعتكم</p>
    </div>
    
    <p>مرحباً فريق المستودع،</p>
    <p>نود إعلامكم بأنه تم رصد واستيراد <strong>({count})</strong> طلبات تحويل مخزون جديدة من نظام SAP بنجاح وينتظر مراجعتها وتأكيد الكميات.</p>
    
    <div class=\"highlight-box\">
        <p style=\"margin:5px 0;\">📦 <b>أرقام مستندات التحويل:</b> {doc_nums}</p>
        <p style=\"margin:5px 0;\">🏢 <b>المستودع المُرسِل (المصدر):</b> {from_warehouse}</p>
        <p style=\"margin:5px 0;\">🎯 <b>المستودع المُستلِم (الوجهة):</b> {to_warehouse}</p>
    </div>
    
    <p>لضمان سير العمليات اللوجستية وتحديث المخزون في الوقت الفعلي، يرجى التكرم بالدخول إلى لوحة تحكم <strong>Muntajat Connect</strong> لمراجعة تفاصيل التحويل والتنفيذ.</p>
    
    <div class=\"button-container\">
        <a href=\"{link}\" class=\"button button-ar\">عرض الطلبات الأن عبر النظام</a>
    </div>";

    $template->body_en = "
    <div style=\"text-align: center; margin-bottom: 25px;\">
        <h2 style=\"color: #2B3A42; margin: 0;\">Muntajat SAP System Alert</h2>
        <p style=\"color: #666; font-size: 14px;\">New stock transfer requests are pending your review.</p>
    </div>
    
    <p>Hello Warehouse Team,</p>
    <p>Please be advised that <strong>({count})</strong> new stock transfer requests have been successfully imported from SAP and require your attention and quantity confirmation.</p>
    
    <div class=\"highlight-box\">
        <p style=\"margin:5px 0;\">📦 <b>Transfer Document Numbers:</b> {doc_nums}</p>
        <p style=\"margin:5px 0;\">🏢 <b>Source Warehouse:</b> {from_warehouse}</p>
        <p style=\"margin:5px 0;\">🎯 <b>Destination Warehouse:</b> {to_warehouse}</p>
    </div>
    
    <p>To ensure smooth logistics and real-time inventory updates, please access the <strong>Muntajat Connect</strong> dashboard to review and process these transfers.</p>
    
    <div class=\"button-container\">
        <a href=\"{link}\" class=\"button button-en\">View Transfers Over the System</a>
    </div>";

    $template->save();
    echo "TEMPLATE UPDATED SUCCESSFULLY\n";
} else {
    echo "TEMPLATE NOT FOUND\n";
}
