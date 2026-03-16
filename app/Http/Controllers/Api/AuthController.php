<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Sms\TaqnyatSmsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;

class AuthController extends Controller
{
    protected $smsService;

    public function __construct(TaqnyatSmsService $smsService)
    {
        $this->smsService = $smsService;
    }

    /**
     * Login
     * 
     * Initiates login. 
     * - Pass `mobile_number` to request an OTP.
     * - Pass `email` and `password` to login using credentials (instant token).
     * 
     * @param \Illuminate\Http\Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function login(Request $request)
    {
        $request->validate([
            'mobile_number' => 'required_without_all:email,password',
            'email' => 'required_without:mobile_number|email',
            'password' => 'required_with:email',
        ]);

        // 1. Email + Password Login
        if ($request->has('email') && $request->has('password')) {
            if (Auth::attempt($request->only('email', 'password'))) {
                $user = Auth::user();

                // Update Last Login
                $user->update([
                    'last_login_at' => Carbon::now(),
                ]);

                // Create Token
                $token = $user->createToken('api-login')->plainTextToken;

                // Append roles
                $user->roles = $user->getRoleNames();

                return response()->json([
                    'message' => 'Login successful',
                    'token' => $token,
                    'user' => $user,
                ]);
            }

            return response()->json(['message' => 'Invalid credentials.'], 401);
        }

        // 2. Mobile OTP Flow
        $rawMobile = $request->input('mobile_number');
        $normalizedMobile = $this->normalizeMobile($rawMobile);

        $user = User::where('mobile_number', $normalizedMobile)->first();

        // Optional: If user doesn't exist, we can register them or deny.
        // For now, let's assume valid users must exist (e.g. created by admin).
        if (!$user) {
            return response()->json(['message' => 'User not found. Contact admin.'], 404);
        }

        // Generate OTP
        $otp = rand(1000, 9999);
        $expiresAt = Carbon::now()->addMinutes(10);

        $user->update([
            'otp_code' => $otp,
            'otp_expires_at' => $expiresAt,
        ]);

        // Send SMS
        $sent = $this->smsService->sendOtp($normalizedMobile, $otp);

        if ($sent) {
            return response()->json(['message' => 'OTP sent successfully.']);
        } else {
            return response()->json(['message' => 'Failed to send OTP. Try again later.'], 500);
        }
    }

    /**
     * Verify OTP
     * 
     * Verifies the OTP and returns an access token.
     * 
     * @param \Illuminate\Http\Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function verifyOtp(Request $request)
    {
        $request->validate([
            'mobile_number' => 'required',
            'otp' => 'required',
        ]);

        $rawMobile = $request->input('mobile_number');
        $normalizedMobile = $this->normalizeMobile($rawMobile);
        $otp = $request->input('otp');

        $user = User::where('mobile_number', $normalizedMobile)->first();

        if (!$user) {
            return response()->json(['message' => 'User not found.'], 404);
        }

        if ($user->otp_code !== $otp) {
            return response()->json(['message' => 'Invalid OTP.'], 400);
        }

        if (Carbon::now()->greaterThan($user->otp_expires_at)) {
            return response()->json(['message' => 'OTP expired.'], 400);
        }

        // OTP Valid
        $user->update([
            'otp_code' => null,
            'otp_expires_at' => null,
            'last_login_at' => Carbon::now(),
        ]);

        // Create Token (assuming Sanctum)
        $token = $user->createToken('mobile-login')->plainTextToken;

        // Append roles
        $user->roles = $user->getRoleNames();

        return response()->json([
            'message' => 'Login successful',
            'token' => $token,
            'user' => $user,
        ]);
    }

    /**
     * Logout
     * 
     * Invalidates the current access token.
     * 
     * @param \Illuminate\Http\Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out successfully']);
    }

    protected function normalizeMobile($mobile)
    {
        // 1. Remove non-digits
        $digits = preg_replace('/\D/', '', $mobile);

        // 2. Handling formats
        // 96650XXXXXXX (12 digits) -> Keep
        // 050XXXXXXX (10 digits) -> Remove 0, add 966
        // 50XXXXXXX (9 digits) -> Add 966

        if (strlen($digits) === 12 && str_starts_with($digits, '966')) {
            return $digits;
        }

        if (strlen($digits) === 10 && str_starts_with($digits, '05')) {
            return '966' . substr($digits, 1);
        }

        if (strlen($digits) === 9 && str_starts_with($digits, '5')) {
            return '966' . $digits;
        }

        // Return original if unknown format, user check will verify it doesn't exist
        return $digits;
    }
}
