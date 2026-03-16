<?php

namespace App\Services\SMS;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class TaqnyatService
{
    protected $baseUrl = 'https://api.taqnyat.sa';
    protected $bearerToken;
    protected $sender;

    public function __construct()
    {
        $this->bearerToken = config('services.taqnyat.bearer_token');
        $this->sender = config('services.taqnyat.sender', 'PPTCO');
    }

    public function sendSms($recipients, $message)
    {
        if (empty($recipients)) {
            return false;
        }

        try {
            $response = Http::withToken($this->bearerToken)
                ->post("{$this->baseUrl}/v1/messages", [
                    'recipients' => is_array($recipients) ? $recipients : [$recipients],
                    'sender' => $this->sender,
                    'body' => $message,
                ]);

            if ($response->successful()) {
                Log::info('Taqnyat SMS Sent', ['recipients' => $recipients, 'response' => $response->json()]);
                return true;
            } else {
                Log::error('Taqnyat SMS Failed', ['error' => $response->body()]);
                return false;
            }
        } catch (\Exception $e) {
            Log::error('Taqnyat SMS Exception', ['message' => $e->getMessage()]);
            return false;
        }
    }
}
