<?php

declare(strict_types=1);

namespace App\Modules\Risk\Services;

final class UncertaintyPenaltyCalculator
{
    /**
     * @return array<string, float>
     */
    private function weights(): array
    {
        return config('risk.uncertainty_weights', [
            'Reported' => 5.0,
            'Confirmed' => 0.0,
            'UncertainConflicting' => 20.0,
        ]);
    }

    public function calculate(string $status): float
    {
        $weights = $this->weights();

        return $weights[$status] ?? 0.0;
    }

    /**
     * Multiple hazards on one segment: use MAX uncertainty (spec).
     *
     * @param  array<int, string>  $statuses
     */
    public function calculateForSegment(array $statuses): float
    {
        if ($statuses === []) {
            return 0.0;
        }

        $penalties = array_map(fn (string $s) => $this->calculate($s), $statuses);

        return max($penalties);
    }
}
