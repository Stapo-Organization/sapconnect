<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    /**
     * Get Profile
     * 
     * Retrieve the authenticated user's profile information.
     * 
     * @param \Illuminate\Http\Request $request
     * @return \App\Http\Resources\UserResource
     */
    public function index(Request $request)
    {
        return new UserResource($request->user());
    }

    /**
     * Update Profile
     * 
     * Update the authenticated user's profile information.
     * 
     * @param \Illuminate\Http\Request $request
     * @return \App\Http\Resources\UserResource
     */
    public function update(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            // 'mobile_number' => ... // usually restricted or requires OTP re-verification
        ]);

        $user->update($validated);

        return new UserResource($user);
    }
}
