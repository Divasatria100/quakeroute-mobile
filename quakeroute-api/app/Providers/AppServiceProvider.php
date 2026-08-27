<?php

namespace App\Providers;

use App\Modules\AI\Contracts\AIProviderInterface;
use App\Modules\AI\Providers\FakeAIProvider;
use App\Modules\AI\Providers\HttpAIProvider;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(AIProviderInterface::class, function () {
            // Demo/testing-safe default: FakeAIProvider is used for hackathon/demo
            // workflows. The HTTP provider is only selected once it is explicitly
            // enabled AND a real API key is configured, so the demo never requires one.
            $provider = config('ai.provider');
            $httpEnabled = in_array($provider, ['http', 'openrouter'], true);
            $hasKey = (string) config('ai.api_key') !== '';

            if ($httpEnabled && $hasKey) {
                return new HttpAIProvider;
            }

            return new FakeAIProvider;
        });
    }

    public function boot(): void
    {
        //
    }
}
