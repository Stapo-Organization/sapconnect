<?php

namespace App\Support;

use Filament\Support\Assets\Theme;

/**
 * The compiled admin theme (public/css/filament/admin/theme.css). Its URL is
 * built per request, so it follows the forced https scheme, and it is
 * versioned by file time so browsers pick up every rebuild.
 */
class AdminTheme extends Theme
{
    public static function compiled(): static
    {
        return static::make('theme', public_path('css/filament/admin/theme.css'))->package('filament/admin');
    }

    public function getVersion(): string
    {
        return (string) (@filemtime($this->getPublicPath()) ?: parent::getVersion());
    }
}
