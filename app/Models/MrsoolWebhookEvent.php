<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Raw log of every Mrsool webhook body we received.
 *
 * Debug aid only — the webhook is UNSIGNED, so nothing here is trusted beyond
 * {id,status}; the service always re-fetches the order from the API.
 */
class MrsoolWebhookEvent extends Model
{
    protected $table = 'mrsool_webhook_events';

    protected $guarded = [];

    public $timestamps = false;

    protected $casts = [
        'payload'    => 'array',
        'processed'  => 'boolean',
        'created_at' => 'datetime',
    ];
}
