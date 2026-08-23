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
            $provider = config('ai.provider', '');
            if ($provider === 'fake' || $provider === '' || app()->environment('testing')) {
                return new FakeAIProvider;
            }

            return new HttpAIProvider;
        });
    }

    public function boot(): void
    {
        //
    }
}
