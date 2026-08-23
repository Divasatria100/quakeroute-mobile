<?php

declare(strict_types=1);

namespace App\Modules\AI\Contracts;

use App\Modules\AI\Support\AIProviderException;

/**
 * Provider-agnostic contract for hazard understanding.
 * Implementations must not leak vendor-specific details to callers.
 */
interface AIProviderInterface
{
    /**
     * Extract structured hazard data from raw report text.
     *
     * @param  string  $reportText  Raw hazard report text
     * @param  array<string, mixed>  $context  Optional context (e.g. location, mode)
     * @return array<string, mixed> Raw decoded structured output from provider
     *
     * @throws AIProviderException On provider failure, timeout, or malformed response
     */
    public function extractHazard(string $reportText, array $context = []): array;
}
