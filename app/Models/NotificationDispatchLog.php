<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * سطر تدقيق لكل إرسال تنبيه مرّ عبر NotificationRouter.
 */
class NotificationDispatchLog extends Model
{
    protected $fillable = [
        'event_key',
        'channels',
        'recipients_count',
        'email_count',
        'push_tokens_count',
        'status',
        'title',
        'error',
    ];
}
