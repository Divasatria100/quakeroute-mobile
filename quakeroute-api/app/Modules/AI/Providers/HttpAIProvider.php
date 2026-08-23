<?php

declare(strict_types=1);

namespace App\Modules\AI\Providers;

use App\Modules\AI\Contracts\AIProviderInterface;
use App\Modules\AI\Prompts\HazardExtractionPrompt;
use App\Modules\AI\Support\AIProviderException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

final class HttpAIProvider implements AIProviderInterface
{
    public function extractHazard(string $reportText, array $context = []): array
    {
        $baseUrl = (string) config('ai.base_url', '');
        $apiKey = (string) config('ai.api_key', '');
        $model = (string) config('ai.model', '');
        $provider = (string) config('ai.provider', '');

        if ($baseUrl === '' || $provider === '') {
            throw AIProviderException::unavailable('AI provider not configured (AI_BASE_URL / AI_PROVIDER empty)');
        }

        $systemPrompt = HazardExtractionPrompt::systemPrompt();
        $userPrompt = HazardExtractionPrompt::userPrompt($reportText, $context);

        // Provider-agnostic payload: keep minimal and clearly mark vendor mapping as TBD.
        // This implementation sends a generic JSON; vendor-specific transformation should be
        // isolated here and documented as TBD if format unknown.
        $payload = [
            'model' => $model !== '' ? $model : null,
            'messages' => [
                ['role' => 'system', 'content' => $systemPrompt],
                ['role' => 'user', 'content' => $userPrompt],
            ],
            'temperature' => 0.2,
        ];
        $payload = array_filter($payload, fn ($v) => $v !== null);

        try {
            $response = Http::withHeaders(array_filter([
                'Authorization' => $apiKey !== '' ? 'Bearer '.$apiKey : null,
                'Accept' => 'application/json',
                'Content-Type' => 'application/json',
            ]))
                ->timeout((int) config('ai.timeout', 15))
                ->post(rtrim($baseUrl, '/').'/chat/completions', $payload);
        } catch (\Throwable $e) {
            Log::warning('AI provider request failed', ['error' => $e->getMessage(), 'provider' => $provider]);
            if (str_contains($e->getMessage(), 'cURL error 28') || str_contains($e->getMessage(), 'timed out')) {
                throw AIProviderException::timeout('AI provider timeout', $e);
            }
            throw AIProviderException::unavailable('AI provider request failed: '.$e->getMessage(), $e);
        }

        if ($response->failed()) {
            Log::warning('AI provider HTTP error', ['status' => $response->status(), 'body' => $response->body()]);
            if ($response->status() >= 500 || $response->status() === 429) {
                throw AIProviderException::unavailable('AI provider HTTP '.$response->status(), new RequestException($response));
            }
            throw AIProviderException::malformed('AI provider HTTP '.$response->status().': '.$response->body());
        }

        $json = $response->json();
        if (! is_array($json)) {
            throw AIProviderException::malformed('AI provider returned non-JSON');
        }

        // Generic extraction: try to find JSON in choices[0].message.content (OpenAI-like) or direct object.
        // Keep vendor mapping isolated and mark as TBD for non-conforming providers.
        $content = null;
        if (isset($json['choices'][0]['message']['content']) && is_string($json['choices'][0]['message']['content'])) {
            $content = $json['choices'][0]['message']['content'];
        } elseif (isset($json['content']) && is_string($json['content'])) {
            $content = $json['content'];
        } elseif (isset($json['type']) && isset($json['severity'])) {
            // Already structured
            return $json;
        }

        if (! is_string($content)) {
            throw AIProviderException::malformed('AI provider response missing structured content');
        }

        $decoded = json_decode($content, true);
        if (json_last_error() !== JSON_ERROR_NONE || ! is_array($decoded)) {
            throw AIProviderException::malformed('AI provider returned invalid JSON: '.json_last_error_msg());
        }

        return $decoded;
    }
}
