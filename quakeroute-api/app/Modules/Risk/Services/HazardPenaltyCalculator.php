<?php

declare(strict_types=1);

namespace App\Modules\Risk\Services;

final class HazardPenaltyCalculator
{
    /**
     * @return array<string, float> severity => weight
     */
    private function weights(): array
    {
        return config('risk.severity_weights', [
            'Low' => 10.0,
            'Medium' => 30.0,
            'High' => 100.0,
        ]);
    }

    public function calculate(string $severity, float $confidence): float
    {
        $weights = $this->weights();
        $weight = $weights[$severity] ?? 0.0;

        // ConfidenceFactor = confidence linear 0..1
        return $weight * $confidence;
    }

    /**
     * For a segment with multiple hazards, use MAX (domain-risk-model.md:10).
     *
     * @param  array<int, array{severity: string, confidence: float}>  $hazards
     */
    public function calculateForSegment(array $hazards): float
    {
        if ($hazards === []) {
            return 0.0;
        }

        $penalties = array_map(fn (array $h) => $this->calculate($h['severity'], $h['confidence']), $hazards);

        return max($penalties);
    }
}
