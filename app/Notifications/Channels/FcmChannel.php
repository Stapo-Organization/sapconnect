<?php

namespace App\Notifications\Channels;

use App\Services\NotificationService;
use Illuminate\Notifications\Notification;

/**
 * قناة إشعار Laravel مخصّصة ترسل Push عبر FCM.
 *
 * يضيفها الإشعار في via() (عادةً بشكل مشروط بتفضيل المستخدم)، وينفّذ
 * toFcm($notifiable) الذي يعيد ['title'=>, 'body'=>, 'data'=>].
 * تعيد الاستخدام الكامل لكود FCM في NotificationService (خامل حتى تثبيت Firebase).
 */
class FcmChannel
{
    public function __construct(protected NotificationService $service)
    {
    }

    public function send(object $notifiable, Notification $notification): void
    {
        if (! method_exists($notification, 'toFcm') || ! method_exists($notifiable, 'getKey')) {
            return;
        }

        $payload = $notification->toFcm($notifiable);
        if (empty($payload['title'])) {
            return;
        }

        $this->service->pushToUsers(
            [$notifiable->getKey()],
            (string) $payload['title'],
            (string) ($payload['body'] ?? ''),
            (array) ($payload['data'] ?? [])
        );
    }
}
