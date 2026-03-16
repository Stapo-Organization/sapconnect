<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ApiLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'method',
        'endpoint',
        'database_name',
        'status_code',
        'request_payload',
        'response_body',
        'ip_address',
        'user_agent',
    ];

    /**
     * Get the user that made the request.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
