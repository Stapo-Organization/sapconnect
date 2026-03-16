<?php

namespace App\Policies;

use App\Models\User;
use App\Models\ApiTransformer;

class ApiTransformerPolicy
{
    /**
     * Determine whether the user can view any models.
     */
    public function viewAny(User $user): bool
    {
        return $user->hasPermissionTo('view_any_api_transformer');
    }

    /**
     * Determine whether the user can view the model.
     */
    public function view(User $user, ApiTransformer $apiTransformer): bool
    {
        return $user->hasPermissionTo('view_api_transformer');
    }

    /**
     * Determine whether the user can create models.
     */
    public function create(User $user): bool
    {
        return $user->hasPermissionTo('create_api_transformer');
    }

    /**
     * Determine whether the user can update the model.
     */
    public function update(User $user, ApiTransformer $apiTransformer): bool
    {
        return $user->hasPermissionTo('update_api_transformer');
    }

    /**
     * Determine whether the user can delete the model.
     */
    public function delete(User $user, ApiTransformer $apiTransformer): bool
    {
        return $user->hasPermissionTo('delete_api_transformer');
    }
}
