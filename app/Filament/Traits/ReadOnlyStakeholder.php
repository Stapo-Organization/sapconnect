<?php

namespace App\Filament\Traits;

use Illuminate\Database\Eloquent\Model;

/**
 * Trait ReadOnlyStakeholder
 *
 * Apply this trait to any Filament Resource to automatically block
 * create, edit, and delete actions for users with the 'Stakeholder' role.
 * Stakeholders get full read-only access to all data.
 */
trait ReadOnlyStakeholder
{
    /**
     * Check if the current user is a Stakeholder.
     */
    public static function isStakeholder(): bool
    {
        return auth()->user()?->hasRole('Stakeholder') ?? false;
    }

    /**
     * Block create for Stakeholders.
     */
    public static function canCreate(): bool
    {
        if (static::isStakeholder()) {
            return false;
        }

        return parent::canCreate();
    }

    /**
     * Block edit for Stakeholders.
     */
    public static function canEdit(Model $record): bool
    {
        if (static::isStakeholder()) {
            return false;
        }

        return parent::canEdit($record);
    }

    /**
     * Block delete for Stakeholders.
     */
    public static function canDelete(Model $record): bool
    {
        if (static::isStakeholder()) {
            return false;
        }

        return parent::canDelete($record);
    }

    /**
     * Block bulk delete for Stakeholders.
     */
    public static function canDeleteAny(): bool
    {
        if (static::isStakeholder()) {
            return false;
        }

        return parent::canDeleteAny();
    }
}
