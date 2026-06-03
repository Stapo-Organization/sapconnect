<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\DeviceToken;
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

    /**
     * Register / refresh this device's push token (multi-device).
     */
    public function updateFcmToken(Request $request)
    {
        $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['nullable', 'string', 'in:ios,android'],
        ]);

        $user = $request->user();

        DeviceToken::updateOrCreate(
            ['token' => $request->token],
            ['user_id' => $user->id, 'platform' => $request->platform, 'last_used_at' => now()]
        );

        // Mirror to users.fcm_token for backward compatibility.
        $user->update(['fcm_token' => $request->token]);

        return response()->json(['message' => 'تم تسجيل الجهاز للإشعارات']);
    }

    /**
     * Remove a device token (logout / token refresh).
     */
    public function deleteFcmToken(Request $request)
    {
        $request->validate(['token' => ['required', 'string']]);

        DeviceToken::where('token', $request->token)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'تم إلغاء تسجيل الجهاز']);
    }
}
