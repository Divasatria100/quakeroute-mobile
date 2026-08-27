<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Modules\AI\Contracts\AIProviderInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class DebugAITest extends TestCase
{
    use RefreshDatabase;

    public function test_debug_env(): void
    {
        dump('APP_ENV env='.getenv('APP_ENV'));
        dump('environment testing='.var_export(app()->environment('testing'), true));
        dump('provider class='.get_class(app(AIProviderInterface::class)));
        dump('config ai.provider='.config('ai.provider'));
        dump('env AI_PROVIDER='.env('AI_PROVIDER'));
        dump('getenv AI_PROVIDER='.getenv('AI_PROVIDER'));
        dump('runningUnitTests='.var_export($this->app->runningUnitTests(), true));
        dump('basePath='.$this->app->basePath());
        $this->assertTrue(true);
    }
}