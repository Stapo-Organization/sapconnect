<?php

namespace App\Services\Creative;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Replicate.com image driver with a hybrid routing:
 *  - product images supplied  → scene_model (nano-banana, image-to-image): the
 *    REAL product is placed into a premium scene.
 *  - no product images        → txt2img_model (Imagen 4 Ultra): a product-free
 *    scene from the prompt.
 * Output is downloaded to the public disk and returned as an absolute path.
 */
class ReplicateImageGenerator implements ImageGeneratorInterface
{
    public function key(): string
    {
        return 'replicate';
    }

    public function generate(string $prompt, array $opts = []): ?string
    {
        $token = (string) config('services.replicate.token');
        if ($token === '') {
            Log::warning('[creative] Replicate token missing.');
            return null;
        }

        $images = array_values(array_filter($opts['image_inputs'] ?? []));
        $aspect = (string) ($opts['aspect_ratio'] ?? '16:9');
        $seed = $opts['seed'] ?? null;
        $base = rtrim((string) config('services.replicate.base_url', 'https://api.replicate.com/v1'), '/');
        $timeout = (int) config('services.replicate.timeout', 120);

        // Route to the right model + build its specific input payload.
        if (! empty($images)) {
            $model = (string) config('services.replicate.scene_model', 'google/nano-banana');
            $input = [
                'prompt' => $prompt,
                'image_input' => $images,
                'aspect_ratio' => $aspect,
                'output_format' => 'jpg',
            ];
        } else {
            $model = (string) config('services.replicate.txt2img_model', 'google/imagen-4-ultra');
            $input = array_filter([
                'prompt' => $prompt,
                'aspect_ratio' => $aspect,
                'seed' => $seed,
            ], fn ($v) => $v !== null);
        }

        try {
            $resp = Http::withToken($token)
                ->withHeaders(['Prefer' => 'wait'])
                ->timeout($timeout)
                ->post("{$base}/models/{$model}/predictions", ['input' => $input]);

            if ($resp->failed()) {
                Log::error('[creative] Replicate create failed', ['model' => $model, 'status' => $resp->status(), 'body' => $resp->body()]);
                return null;
            }

            $pred = $this->awaitCompletion($resp->json(), $token, $timeout);
            if (($pred['status'] ?? null) !== 'succeeded') {
                Log::error('[creative] prediction not succeeded', ['model' => $model, 'status' => $pred['status'] ?? null, 'error' => $pred['error'] ?? null]);
                return null;
            }

            $url = $this->firstOutputUrl($pred['output'] ?? null);
            return $url ? $this->download($url) : null;
        } catch (\Throwable $e) {
            Log::error('[creative] Replicate exception: ' . $e->getMessage());
            return null;
        }
    }

    private function awaitCompletion(array $pred, string $token, int $timeout): array
    {
        $terminal = ['succeeded', 'failed', 'canceled'];
        $deadline = time() + $timeout;
        $getUrl = $pred['urls']['get'] ?? null;
        while (! in_array($pred['status'] ?? '', $terminal, true) && $getUrl && time() < $deadline) {
            usleep(1_500_000);
            $poll = Http::withToken($token)->timeout($timeout)->get($getUrl);
            if ($poll->failed()) {
                break;
            }
            $pred = $poll->json();
        }
        return $pred;
    }

    private function firstOutputUrl(mixed $output): ?string
    {
        if (is_string($output)) {
            return $output;
        }
        if (is_array($output)) {
            $first = $output[0] ?? null;
            return is_string($first) ? $first : null;
        }
        return null;
    }

    private function download(string $url): ?string
    {
        $bytes = Http::timeout(60)->get($url);
        if ($bytes->failed()) {
            Log::error('[creative] download failed', ['url' => $url]);
            return null;
        }
        $ext = pathinfo(parse_url($url, PHP_URL_PATH) ?: '', PATHINFO_EXTENSION) ?: 'jpg';
        $relative = 'creatives/bases/' . Str::uuid()->toString() . '.' . $ext;
        Storage::disk('public')->put($relative, $bytes->body());
        return Storage::disk('public')->path($relative);
    }
}
