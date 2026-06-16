<?php

namespace App\Services\Creative;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * OpenAI gpt-image-2 (via Replicate) driver. Unlike the nano/Imagen drivers this
 * renders the COMPLETE finished banner in one step — scene + the REAL product(s)
 * (passed as input_images) + correctly-shaped Arabic text + brand identity/logo —
 * so NO separate resvg compositing is needed. It is the only model that renders
 * Arabic correctly and accepts reference product/logo images together.
 *
 * Slower (~60–180s) and pricier than nano/Imagen, so the caller controls how many
 * images per campaign it requests (see GenerateAdCreative). Supported aspect
 * ratios: 1:1, 3:2, 2:3.
 */
class GptImageGenerator implements ImageGeneratorInterface
{
    public function key(): string
    {
        return 'gpt-image';
    }

    public function generate(string $prompt, array $opts = []): ?string
    {
        $token = (string) config('services.replicate.token');
        if ($token === '') {
            Log::warning('[creative] Replicate token missing.');
            return null;
        }

        $model = (string) config('services.replicate.gpt_image_model', 'openai/gpt-image-2');
        $base = rtrim((string) config('services.replicate.base_url', 'https://api.replicate.com/v1'), '/');
        $timeout = (int) config('services.replicate.gpt_image_timeout', 300);

        $images = array_values(array_filter($opts['image_inputs'] ?? []));
        $aspect = $this->normalizeAspect((string) ($opts['aspect_ratio'] ?? '3:2'));

        $input = array_filter([
            'prompt' => $prompt,
            'input_images' => $images,
            'aspect_ratio' => $aspect,
            'quality' => (string) ($opts['quality'] ?? config('services.replicate.gpt_image_quality', 'high')),
            'output_format' => 'png',
            'number_of_images' => 1,
        ], fn ($v) => $v !== null && $v !== []);

        try {
            $resp = Http::withToken($token)
                ->timeout($timeout)
                ->post("{$base}/models/{$model}/predictions", ['input' => $input]);

            if ($resp->failed()) {
                Log::error('[creative] gpt-image create failed', ['status' => $resp->status(), 'body' => $resp->body()]);
                return null;
            }

            $pred = $this->awaitCompletion($resp->json(), $token, $timeout);
            if (($pred['status'] ?? null) !== 'succeeded') {
                Log::error('[creative] gpt-image not succeeded', ['status' => $pred['status'] ?? null, 'error' => $pred['error'] ?? null]);
                return null;
            }

            $url = $this->firstOutputUrl($pred['output'] ?? null);
            return $url ? $this->download($url) : null;
        } catch (\Throwable $e) {
            Log::error('[creative] gpt-image exception: ' . $e->getMessage());
            return null;
        }
    }

    /** gpt-image-2 only supports 1:1 / 3:2 / 2:3 — snap anything else to the nearest. */
    private function normalizeAspect(string $aspect): string
    {
        if (in_array($aspect, ['1:1', '3:2', '2:3'], true)) {
            return $aspect;
        }
        [$w, $h] = array_pad(array_map('floatval', explode(':', $aspect) + [0, 1]), 2, 1);
        if ($h <= 0) {
            return '3:2';
        }
        $r = $w / $h;
        return $r >= 1.25 ? '3:2' : ($r <= 0.8 ? '2:3' : '1:1');
    }

    private function awaitCompletion(array $pred, string $token, int $timeout): array
    {
        $terminal = ['succeeded', 'failed', 'canceled'];
        $deadline = time() + $timeout;
        $getUrl = $pred['urls']['get'] ?? null;
        while (! in_array($pred['status'] ?? '', $terminal, true) && $getUrl && time() < $deadline) {
            sleep(5);
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
        $bytes = Http::timeout(120)->get($url);
        if ($bytes->failed()) {
            Log::error('[creative] gpt-image download failed', ['url' => $url]);
            return null;
        }
        $relative = 'creatives/bases/' . Str::uuid()->toString() . '.png';
        Storage::disk('public')->put($relative, $bytes->body());
        return Storage::disk('public')->path($relative);
    }
}
