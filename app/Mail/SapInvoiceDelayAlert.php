<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;
use App\Models\EmailNotification;

class SapInvoiceDelayAlert extends Mailable
{
    use Queueable, SerializesModels;

    public $template;
    public $lastInvoiceTime;
    public $delayMinutes;

    public function __construct(EmailNotification $template, string $lastInvoiceTime, int $delayMinutes)
    {
        $this->template = $template;
        $this->lastInvoiceTime = $lastInvoiceTime;
        $this->delayMinutes = $delayMinutes;
    }

    public function build()
    {
        $subject = $this->template->subject_ar ?: 'تحذير: تأخر استلام فواتير SAP السبت';

        // simple string replacement if user includes variables in body
        $body = $this->template->body_ar ?: 'يرجى العلم بأنه لم يتم استلام أي فواتير بيع من ساب خلال الـ 5 دقائق الماضية.';
        $body = str_replace('{last_time}', $this->lastInvoiceTime, $body);
        $body = str_replace('{delay_minutes}', $this->delayMinutes, $body);

        return $this->subject($subject)
                    ->html($this->getDefaultHtml($body));
    }

    private function getDefaultHtml($body)
    {
        return "
        <div dir='rtl' style='font-family: Arial, sans-serif; color: #333; line-height: 1.6;'>
            <h2 style='color: #e53e3e;'> تنبيه تأخر فواتير SAP</h2>
            <p>{$body}</p>
            <p><strong>وقت آخر فاتورة تم استلامها:</strong> {$this->lastInvoiceTime}</p>
            <p><strong>مدة التأخير حتى الآن:</strong> {$this->delayMinutes} دقيقة</p>
            <hr style='border: 0; border-top: 1px solid #ccc;' />
            <p style='font-size: 12px; color: #777;'>هذا إيميل تلقائي من نظام اللوجستيات. يرجى مراجعة حالة الخوادم.</p>
        </div>
        ";
    }
}
