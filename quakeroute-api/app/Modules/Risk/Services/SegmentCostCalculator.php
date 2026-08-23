<?php

declare(strict_types=1);

namespace App\Modules\Risk\Services;

final class SegmentCostCalculator
{
    private const ROAD_IMPACT_ORDER = [
        'Passable' => 0,
        'PartiallyBlocked' => 1,
        'Blocked' => 2,
    ];

    public function __construct(
        private readonly HazardPenaltyCalculator $hazardPenaltyCalculator,
        private readonly UncertaintyPenaltyCalculator $uncertaintyPenaltyCalculator,
    ) {}

    public function worstRoadImpact(array $roadImpacts): string
    {
        if ($roadImpacts === []) {
            return 'Passable';
        }

        $max = 'Passable';
        $maxOrder = -1;
        foreach ($roadImpacts as $ri) {
            $order = self::ROAD_IMPACT_ORDER[$ri] ?? -1;
            if ($order > $maxOrder) {
                $maxOrder = $order;
                $max = $ri;
            }
        }

        return $max;
    }

    /**
     * @param  array<int, array{severity: string, confidence: float, roadImpact: string, status: string}>  $hazards
     */
    public function calculate(float $baseTravelCost, array $hazards): float
    {
        if ($hazards === []) {
            return $baseTravelCost;
        }

        $roadImpacts = array_column($hazards, 'roadImpact');
        $worst = $this->worstRoadImpact($roadImpacts);

        if ($worst === 'Blocked') {
            return (float) config('risk.blocked_cost', PHP_INT_MAX);
        }

        $hazardInputs = array_map(fn (array $h) => ['severity' => $h['severity'], 'confidence' => $h['confidence']], $hazards);
        $statuses = array_column($hazards, 'status');

        $hazardPenalty = $this->hazardPenaltyCalculator->calculateForSegment($hazardInputs);
        $uncertaintyPenalty = $this->uncertaintyPenaltyCalculator->calculateForSegment($statuses);

        return $baseTravelCost + $hazardPenalty + $uncertaintyPenalty;
    }
}
