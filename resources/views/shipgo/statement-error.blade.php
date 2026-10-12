<!DOCTYPE html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>كشف الحساب</title>
<style>body{font-family:Cairo,sans-serif;background:#f9fafb;color:#111827;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.card{background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:32px;max-width:560px}
h1{font-size:18px;margin:0 0 8px}p{color:#6b7280;margin:0 0 6px}code{direction:ltr;display:block;background:#f3f4f6;padding:8px;border-radius:6px;margin-top:12px;font-size:12px}</style></head>
<body><div class="card"><h1>تعذّر إنشاء كشف الحساب</h1>
<p>العميل: {{ $customer->card_code }} — {{ $customer->card_name }}</p>
<p>لم يستطع النظام قراءة البيانات من SAP. تحقق من صلاحيات المستخدم في شركة {{ config('sap.shipgo_company_db') }}.</p>
<code>{{ $message }}</code></div></body></html>
