<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Customer extends Model
{
    use HasFactory;

    protected $fillable = [
        'card_code',
        'card_name',
        'card_type',
        'phone1',
        'contact_person',
        'vat_liable',
        'federal_tax_id',
        'cellular',
        'city',
        'county',
        'country',
        'mail_city',
        'mail_county',
        'mail_country',
        'email_address',
        'ship_to_default',
        'company_registration_number',
        'u_portal_sync',
        'u_iban',
        'create_date',
        'create_time',
        'update_date',
        'update_time',
    ];
}
