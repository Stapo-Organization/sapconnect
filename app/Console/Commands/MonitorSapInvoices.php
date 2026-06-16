<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Automation;
use App\Models\AutomationLog;
use App\Models\SapInvoice;
use App\Models\EmailNotification;
use App\Services\NotificationRouter;
use App\Support\NotificationAudience;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;
use App\Mail\SapInvoiceDelayAlert;

class MonitorSapInvoices extends Command
{
    protected $signature = 'sap:monitor-invoices';
    protected $description = 'Monitor if SAP invoices are delayed during operational hours';

    public function handle()
    {
        $automation = Automation::where('command_signature', $this->signature)->first();
        if ($automation) {
            $automation->update(['last_run_at' => now(), 'last_run_status' => 'running']);
        }

        try {
            $now = Carbon::now();
            $hour = $now->hour;

            // Only run between 9 AM and 11:59 PM (23:59)
            if ($hour < 9) {
                // Not in operational hours
                if ($automation) {
                    $automation->update(['last_run_status' => 'success']);
                }
                return;
            }

            // Get the last invoice created_at
            $lastInvoice = SapInvoice::orderBy('created_at', 'desc')->first();
            
            if (!$lastInvoice) {
                 if ($automation) {
                    $automation->update(['last_run_status' => 'success']);
                 }
                 return; 
            }

            $lastTime = $lastInvoice->created_at;
            $diffMinutes = $lastTime->diffInMinutes($now);

            if ($diffMinutes > 30) {
                // It has been more than 30 minutes since the last invoice was synced
                $this->triggerAlert($lastTime, $diffMinutes);
            } else {
                // healthy state, clear the spam prevention cache so if it goes down later, it can alert immediately
                $this->triggerRecoveryIfNeeded($lastTime);
                Cache::forget('sap_delay_alert_sent');
            }

            if ($automation) {
                $automation->update(['last_run_status' => 'success']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'success', 'message' => "Checked invoices successfully."]);
            }

        } catch (\Exception $e) {
            $msg = "Error monitoring invoices: " . $e->getMessage();
            Log::error($msg);
            if ($automation) {
                $automation->update(['last_run_status' => 'failed']);
                AutomationLog::create(['automation_id' => $automation->id, 'status' => 'failed', 'message' => $msg]);
            }
        }
    }

    private function triggerRecoveryIfNeeded($lastTime)
    {
        if (!Cache::has('sap_delay_alert_sent')) {
            return; // Was healthy anyway
        }

        $template = EmailNotification::where('event_name', 'sap_invoice_recovery')->first();
        if (!$template || !$template->is_active) {
            return;
        }

        // توجيه موحّد: بريد (Mailable القالب) + Push حسب تفضيل كل مستلم.
        // المستلمون من أدوار القالب؛ الـ cc_emails تُراسَل دائماً (لا تفضيل).
        // لا dedupe هنا — التعافي محكوم بفحص Cache::has أعلاه ثم يُنسى المفتاح في المسار الصحي.
        app(NotificationRouter::class)->route(
            'sap_invoice_recovery',
            NotificationAudience::byRoles($template->recipient_roles ?? []),
            [
                'mailable'  => new \App\Mail\SapInvoiceRecoveryAlert($template, $lastTime->toDateTimeString()),
                'cc_emails' => $template->cc_emails ?? [],
                'title'     => 'تعافي مزامنة فواتير SAP',
                'body'      => 'استؤنفت مزامنة فواتير SAP بنجاح.',
                'data'      => ['type' => 'sap_invoice_recovery'],
            ]
        );

        Log::info("Routed SAP Invoice Recovery Alert (event=sap_invoice_recovery).");
    }

    private function triggerAlert($lastTime, $diffMinutes)
    {
        $template = EmailNotification::where('event_name', 'sap_invoice_delay')->first();
        if (!$template || !$template->is_active) {
            Log::warning("sap_invoice_delay email template not found or inactive.");
            return;
        }

        // توجيه موحّد: بريد (Mailable القالب) + Push حسب تفضيل كل مستلم.
        // حارس التكرار (مرة/ساعة) انتقل إلى الموجِّه عبر dedupe_key/dedupe_ttl،
        // ويُضبط بعد إرسال ناجح فقط (إن فشل البريد يُعاد المحاولة في التشغيل التالي).
        app(NotificationRouter::class)->route(
            'sap_invoice_delay',
            NotificationAudience::byRoles($template->recipient_roles ?? []),
            [
                'mailable'  => new SapInvoiceDelayAlert($template, $lastTime->toDateTimeString(), $diffMinutes),
                'cc_emails' => $template->cc_emails ?? [],
                'title'     => 'تأخّر مزامنة فواتير SAP',
                'body'      => "لم تصل فواتير SAP منذ {$diffMinutes} دقيقة.",
                'data'      => ['type' => 'sap_invoice_delay'],
            ],
            ['dedupe_key' => 'sap_delay_alert_sent', 'dedupe_ttl' => 60]
        );

        Log::info("Routed SAP Invoice Delay Alert (delay {$diffMinutes} min, event=sap_invoice_delay).");
    }
}
