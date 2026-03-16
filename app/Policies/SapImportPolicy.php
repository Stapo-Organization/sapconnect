<?php

namespace App\Policies;

use App\Models\SapImport;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class SapImportPolicy
{
    /**
     * Determine whether the user can view any models.
     */
    public function viewAny(User $user): bool
    {
        return $user->hasPermissionTo('view_any_sap_import');
    }

    /**
     * Determine whether the user can view the model.
     */
    public function view(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('view_sap_import');
    }

    /**
     * Determine whether the user can create models.
     */
    public function create(User $user): bool
    {
        return $user->hasPermissionTo('create_sap_import');
    }

    /**
     * Determine whether the user can update the model.
     */
    public function update(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('update_sap_import');
    }

    /**
     * Determine whether the user can delete the model.
     */
    public function delete(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('delete_sap_import');
    }

    /**
     * Determine whether the user can restore the model.
     */
    public function restore(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('create_sap_import'); // Usually same as create or specific permission
    }

    /**
     * Determine whether the user can permanently delete the model.
     */
    public function forceDelete(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('delete_sap_import');
    }

    /**
     * Determine whether the user can download the template.
     */
    public function downloadTemplate(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('download_template_sap_import');
    }

    /**
     * Determine whether the user can run the import.
     */
    public function runImport(User $user, SapImport $sapImport): bool
    {
        return $user->hasPermissionTo('run_import_sap_import');
    }
}
