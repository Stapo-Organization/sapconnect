<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TaqnyatSmsService
{
    protected $baseUrl = 'https://api.taqnyat.sa/v1';

    public function sendOtp($mobile, $otp)
    {
        $bearerToken = config('services.taqnyat.bearer_token');
        $sender = config('services.taqnyat.sender');

        if (empty($bearerToken)) {
            Log::error('Taqnyat Bearer Token is not configured.');
            return false;
        }

        $message = "Your OTP code is: {$otp}";

        try {
            $response = Http::get("{$this->baseUrl}/messages", [
                'bearerTokens' => $bearerToken,
                'sender' => $sender,
                'recipients' => $mobile,
                'body' => $message,
            ]);

            if ($response->successful()) {
                Log::info("SMS sent successfully to {$mobile}");
                return true;
            } else {
                Log::error("Failed to send SMS to {$mobile}: " . $response->body());
                return false;
            }
        } catch (\Exception $e) {
            Log::error("Exception sending SMS to {$mobile}: " . $e->getMessage());
            return false;
        }
    }
}
