<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;
use App\Models\EmailNotification;

class SapInvoiceRecoveryAlert extends Mailable
{
    use Queueable, SerializesModels;

    public $template;
    public $lastInvoiceTime;

    public function __construct(EmailNotification $template, string $lastInvoiceTime)
    {
        $this->template = $template;
        $this->lastInvoiceTime = $lastInvoiceTime;
    }

    public function build()
    {
        $subject = $this->template->subject_ar ?: 'تم الحل: استئناف استلام فواتير SAP بنجاح';

        $body = $this->template->body_ar ?: 'تم استئناف استلام فواتير المبيعات من ساب بنجاح والنظام الآن يعمل بشكل طبيعي.';
        $body = str_replace('{last_time}', $this->lastInvoiceTime, $body);

        return $this->subject($subject)
                    ->html($this->getDefaultHtml($body));
    }

    private function getDefaultHtml($body)
    {
        return "
        <div dir='rtl' style='font-family: Arial, sans-serif; color: #333; line-height: 1.6;'>
            <h2 style='color: #38a169;'>✅ تم استئناف الربط واستلام الفواتير</h2>
            <p>{$body}</p>
            <p><strong>وقت أحدث فاتورة متزامنة:</strong> {$this->lastInvoiceTime}</p>
            <hr style='border: 0; border-top: 1px solid #ccc;' />
            <p style='font-size: 12px; color: #777;'>نظام المراقبة الذكي للوجستيات.</p>
        </div>
        ";
    }
}
