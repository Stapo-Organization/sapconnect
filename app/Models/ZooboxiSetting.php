<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Key/value store for owner-tunable Zooboxi intelligence settings.
 */
class ZooboxiSetting extends Model
{
    protected $guarded = [];

    public static function get(string $key, $default = null)
    {
        $row = self::where('key', $key)->first();
        return $row ? $row->value : $default;
    }

    public static function set(string $key, $value): self
    {
        return self::updateOrCreate(['key' => $key], ['value' => $value]);
    }
}
