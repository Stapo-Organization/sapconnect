<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Mrsool\MrsoolDeliveryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Mrsool (مرسول) status webhook — PUBLIC (no sanctum).
 *
 * Mrsool signs nothing, so the only credential is a long random token embedded
 * in the URL path, compared with hash_equals. Even then the payload is treated
 * as a HINT: the service re-fetches the order from the API before trusting
 * anything beyond {id,status}. Always answers 200 so Mrsool does not retry a
 * body we have already stored.
 */
class MrsoolWebhookController extends Controller
{
    public function handle(Request $request, string $token, MrsoolDeliveryService $mrsool)
    {
        $expected = (string) config('services.mrsool.webhook_token', '');

        if ($expected === '' || !hash_equals($expected, $token)) {
            Log::warning('mrsool: webhook rejected (bad token)', [
                'context' => 'mrsool',
                'ip'      => $request->ip(),
            ]);
            return response()->json(['message' => 'forbidden'], 403);
        }

        $payload = $request->all();

        try {
            $known = $mrsool->handleWebhook($payload);
        } catch (\Throwable $e) {
            // Never make Mrsool retry because of a bug on our side — the raw
            // body is already logged in mrsool_webhook_events.
            Log::error('mrsool: webhook handling failed: ' . $e->getMessage(), ['context' => 'mrsool']);
            return response()->json(['received' => true], 200);
        }

        return response()->json(['received' => true], $known ? 200 : 202);
    }
}
