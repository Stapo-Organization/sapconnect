<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AlrajhiTransaction extends Model
{
    use HasFactory;

    protected $table = 'alrajhi_transactions';

    protected $fillable = [
        'unique_hash',
        'msg_reference',
        'creation_date',
        'sap_card_code',
        'transfer_customer_name',
        'sap_customer_name',
        'amount',
        'customer_iban',
        'payment_iban',
        'invoices',
        'status',
        'raw_data',
    ];

    protected $casts = [
        'creation_date' => 'datetime',
        'invoices' => 'array',
        'raw_data' => 'array',
    ];
}
