<?php

namespace App\Services;

use App\Mail\DynamicNotificationMail;
use App\Models\EmailLog;
use App\Models\NotificationDispatchLog;
use App\Support\NotificationAudience;
use App\Support\NotificationPreferences;
use Illuminate\Mail\Mailable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * الموجِّه الموحّد للتنبيهات.
 *
 * كل تنبيه (غير المبني على Laravel Notification) يمرّ من هنا: نحلّ المستلمين
 * كنماذج User، ثم لكل مستلم نطبّق تفضيل قناته (بريد/Push) من
 * NotificationPreferences، ونفرّع للقنوات المفعّلة فقط — مع الحفاظ على
 * قوالب البريد القابلة للتحرير وحارس التكرار، وتسجيل كل إرسال للتدقيق.
 *
 * التنبيهات المبنية على Notification (العقود/المالية) تستخدم via() المدرك
 * للتفضيل + FcmChannel وتقرأ نفس NotificationPreferences::channelsFor.
 */
class NotificationRouter
{
    public function __construct(protected NotificationService $fcm)
    {
    }

    /**
     * يحلّ الجمهور حسب audience_roles من الكتالوج ثم يوجّه (للأحداث ذات الجمهور القائم على الأدوار).
     */
    public function dispatch(string $eventKey, array $payload = [], array $opts = []): void
    {
        $this->route($eventKey, NotificationAudience::resolve($eventKey), $payload, $opts);
    }

    /**
     * يوجّه حدثاً لمجموعة مستلمين (User models) محترماً تفضيل قناة كل مستلم.
     *
     * @param iterable $recipients نماذج User
     * @param array $payload [
     *     'title'           => string,     // عنوان Push (عربي)
     *     'body'            => string,     // نص Push
     *     'data'            => array,      // حمولة FCM (توجيه deep-link)
     *     'email_variables' => array,      // متغيّرات {placeholder} لقالب البريد
     *     'mailable'        => Mailable,   // بديل القالب: Mailable جاهز (مثل تنبيهات SAP)
     *     'cc_emails'       => string[],   // عناوين تُراسَل دائماً (لا تخضع للتفضيل)
     * ]
     * @param array $opts [
     *     'force_channels'  => ?string[],  // ['push'] أو ['email','push'] — يتجاوز التفضيل
     *     'dedupe_key'      => ?string,    // مفتاح حارس التكرار (Cache)
     *     'dedupe_ttl'      => ?int,       // مدة الحارس بالدقائق (افتراضي 60)
     * ]
     */
    public function route(string $eventKey, iterable $recipients, array $payload = [], array $opts = []): void
    {
        $dedupeKey = $opts['dedupe_key'] ?? null;
        if ($dedupeKey && Cache::has($dedupeKey)) {
            Log::info("NotificationRouter: '{$eventKey}' suppressed (dedupe '{$dedupeKey}').");
            return;
        }

        $recipients = collect($recipients)->filter()->unique('id')->values();
        $force = $opts['force_channels'] ?? null;

        // تقسيم المستلمين حسب القناة المفعّلة لكل واحد.
        $emailUsers  = collect();
        $pushUserIds = [];
        foreach ($recipients as $user) {
            $channels = $force
                ? ['email' => in_array('email', $force, true), 'push' => in_array('push', $force, true)]
                : NotificationPreferences::channelsFor($user, $eventKey);

            if (($channels['email'] ?? false) && ! empty($user->email)) {
                $emailUsers->push($user);
            }
            if ($channels['push'] ?? false) {
                $pushUserIds[] = $user->id;
            }
        }

        $usedChannels = [];
        $emailCount   = 0;
        $pushTokens   = 0;
        $error        = null;

        // ── البريد ──────────────────────────────────────────────
        // نبني الـ Mailable أولاً ليأتي معه cc القالب (عناوين تُراسَل دائماً).
        [$mailable, $subject, $templateCc] = $this->buildMailable($eventKey, $payload);

        $addresses = $emailUsers->pluck('email')->filter()->all();
        $cc        = array_filter(array_merge($payload['cc_emails'] ?? [], $templateCc)); // لا تخضع للتفضيل
        $allEmail  = array_values(array_unique(array_merge($addresses, $cc)));

        if (! empty($allEmail)) {
            if ($mailable) {
                try {
                    Mail::to($allEmail)->send($mailable);
                    $emailCount     = count($allEmail);
                    $usedChannels[] = 'email';
                    EmailLog::create([
                        'recipient' => implode(', ', $allEmail),
                        'subject'   => $subject,
                        'status'    => 'success',
                        'sent_at'   => now(),
                    ]);
                } catch (\Throwable $e) {
                    $error = $e->getMessage();
                    EmailLog::create([
                        'recipient'     => implode(', ', $allEmail),
                        'subject'       => $subject,
                        'status'        => 'failed',
                        'error_message' => $e->getMessage(),
                        'sent_at'       => now(),
                    ]);
                    Log::error("NotificationRouter: email failed for '{$eventKey}': " . $e->getMessage());
                }
            }
        }

        // ── Push ────────────────────────────────────────────────
        if (! empty($pushUserIds) && ! empty($payload['title'])) {
            try {
                $pushTokens = $this->fcm->pushToUsers(
                    $pushUserIds,
                    (string) $payload['title'],
                    (string) ($payload['body'] ?? ''),
                    (array) ($payload['data'] ?? [])
                );
                if ($pushTokens > 0) {
                    $usedChannels[] = 'push';
                }
            } catch (\Throwable $e) {
                $error = $error ? $error . ' | ' . $e->getMessage() : $e->getMessage();
                Log::error("NotificationRouter: push failed for '{$eventKey}': " . $e->getMessage());
            }
        }

        // ── تدقيق ───────────────────────────────────────────────
        $status = $error
            ? (empty($usedChannels) ? 'failed' : 'partial')
            : (empty($usedChannels) ? 'skipped' : 'success');

        NotificationDispatchLog::create([
            'event_key'         => $eventKey,
            'channels'          => implode(',', $usedChannels),
            'recipients_count'  => $recipients->count(),
            'email_count'       => $emailCount,
            'push_tokens_count' => $pushTokens,
            'status'            => $status,
            'title'             => $payload['title'] ?? null,
            'error'             => $error,
        ]);

        // ضبط حارس التكرار بعد إرسال ناجح (بالدقائق → ثوانٍ).
        if ($dedupeKey && empty($error)) {
            Cache::put($dedupeKey, true, ($opts['dedupe_ttl'] ?? 60) * 60);
        }
    }

    /**
     * يبني الـ Mailable للبريد: Mailable جاهز من الحمولة (SAP) أو قالب DB قابل للتحرير.
     *
     * @return array{0: ?Mailable, 1: string, 2: array} [الـ Mailable أو null, نص الموضوع للسجل, عناوين cc القالب]
     */
    protected function buildMailable(string $eventKey, array $payload): array
    {
        // 1) Mailable جاهز (مثل SapInvoiceDelayAlert) — يحمل قالبه وموضوعه بنفسه؛ الـ cc يأتي من الحمولة.
        if (! empty($payload['mailable']) && $payload['mailable'] instanceof Mailable) {
            return [$payload['mailable'], "[{$eventKey}]", []];
        }

        // 2) قالب DB قابل للتحرير (event_name = المفتاح).
        $def = NotificationPreferences::event($eventKey);
        if (! empty($def['email_template'])) {
            $tpl = EmailNotificationService::render($eventKey, $payload['email_variables'] ?? []);
            if ($tpl && $tpl['is_active']) {
                $mailable = new DynamicNotificationMail(
                    $tpl['subject_ar'],
                    $tpl['subject_en'],
                    $tpl['body_ar'],
                    $tpl['body_en']
                );
                return [$mailable, $tpl['subject_ar'] . ' | ' . $tpl['subject_en'], $tpl['cc_emails']];
            }
        }

        // لا محتوى بريد متاح → تخطّي البريد بهدوء.
        return [null, '', []];
    }
}
