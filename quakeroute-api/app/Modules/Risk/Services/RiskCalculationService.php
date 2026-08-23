<?php

declare(strict_types=1);

namespace App\Modules\Risk\Services;

use App\Modules\Risk\Contracts\RiskCalculatorInterface;

final class RiskCalculationService implements RiskCalculatorInterface
{
    public function __construct(
        private readonly HazardPenaltyCalculator $hazardPenaltyCalculator,
        private readonly UncertaintyPenaltyCalculator $uncertaintyPenaltyCalculator,
        private readonly SegmentCostCalculator $segmentCostCalculator,
    ) {}

    public function calculateHazardPenalty(string $severity, float $confidence): float
    {
        return $this->hazardPenaltyCalculator->calculate($severity, $confidence);
    }

    public function calculateUncertaintyPenalty(string $status): float
    {
        return $this->uncertaintyPenaltyCalculator->calculate($status);
    }

    public function calculateSegmentCost(float $baseTravelCost, array $hazards, array $statuses, string $worstRoadImpact): float
    {
        // Direct path for routing that already resolved worst impact
        if ($worstRoadImpact === 'Blocked') {
            return (float) config('risk.blocked_cost', PHP_INT_MAX);
        }

        $hazardPenalty = $this->hazardPenaltyCalculator->calculateForSegment($hazards);
        $uncertaintyPenalty = $this->uncertaintyPenaltyCalculator->calculateForSegment($statuses);

        return $baseTravelCost + $hazardPenalty + $uncertaintyPenalty;
    }

    /**
     * Convenience: calculate from full hazard list (used by GraphBuilder).
     *
     * @param  array<int, array{severity: string, confidence: float, roadImpact: string, status: string}>  $hazards
     */
    public function calculateForHazards(float $baseTravelCost, array $hazards): float
    {
        return $this->segmentCostCalculator->calculate($baseTravelCost, $hazards);
    }
}
