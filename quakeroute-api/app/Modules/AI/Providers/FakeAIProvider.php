<?php

declare(strict_types=1);

namespace App\Modules\AI\Providers;

use App\Modules\AI\Contracts\AIProviderInterface;
use App\Modules\AI\Support\AIProviderException;

final class FakeAIProvider implements AIProviderInterface
{
    /**
     * @param  array<string, mixed>|null  $nextResult  If set, returned verbatim (for deterministic tests)
     * @param  \Throwable|null  $nextException  If set, thrown instead of returning
     */
    public function __construct(
        private ?array $nextResult = null,
        private ?\Throwable $nextException = null,
    ) {}

    public function setNextResult(?array $result): void
    {
        $this->nextResult = $result;
        $this->nextException = null;
    }

    public function setNextException(\Throwable $e): void
    {
        $this->nextException = $e;
        $this->nextResult = null;
    }

    public function setNextRaw(string $raw): void
    {
        // Simulate malformed JSON case — provider would normally decode, here we throw malformed
        $this->nextException = AIProviderException::malformed('Fake provider raw: '.$raw);
        $this->nextResult = null;
    }

    public function extractHazard(string $reportText, array $context = []): array
    {
        if ($this->nextException !== null) {
            $e = $this->nextException;
            $this->nextException = null;
            if ($e instanceof AIProviderException) {
                throw $e;
            }
            throw new AIProviderException($e->getMessage(), 0, $e);
        }

        if ($this->nextResult !== null) {
            $result = $this->nextResult;
            $this->nextResult = null;

            return $result;
        }

        // Default deterministic mapping based on report text heuristics (for offline testing without explicit setup)
        $lower = mb_strtolower($reportText);

        // Blocked road heuristic
        if (str_contains($lower, 'tidak dapat lewat') || str_contains($lower, 'tidak bisa lewat') || str_contains($lower, 'cannot pass') || str_contains($lower, 'blocked') || str_contains($lower, 'tertutup pohon besar')) {
            return [
                'type' => 'RoadBlockage',
                'severity' => 'High',
                'roadImpact' => 'Blocked',
                'confidence' => 0.92,
                'latitude' => null,
                'longitude' => null,
                'evidence' => mb_substr($reportText, 0, 200),
            ];
        }

        if (str_contains($lower, 'genang') || str_contains($lower, 'tergenang') || str_contains($lower, 'shallow water') || str_contains($lower, 'still pass')) {
            return [
                'type' => 'Flood',
                'severity' => 'Low',
                'roadImpact' => 'Passable',
                'confidence' => 0.78,
                'latitude' => null,
                'longitude' => null,
                'evidence' => mb_substr($reportText, 0, 200),
            ];
        }

        return [
            'type' => 'DebrisRubble',
            'severity' => 'Medium',
            'roadImpact' => 'PartiallyBlocked',
            'confidence' => 0.75,
            'latitude' => null,
            'longitude' => null,
            'evidence' => mb_substr($reportText, 0, 200),
        ];
    }
}
