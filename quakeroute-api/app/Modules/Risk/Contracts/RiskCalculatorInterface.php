<?php

declare(strict_types=1);

namespace App\Modules\Risk\Contracts;

interface RiskCalculatorInterface
{
    /**
     * Calculate hazard penalty for a single hazard (SeverityWeight * Confidence).
     */
    public function calculateHazardPenalty(string $severity, float $confidence): float;

    /**
     * Calculate uncertainty penalty from status.
     */
    public function calculateUncertaintyPenalty(string $status): float;

    /**
     * Calculate routing cost for a segment.
     *
     * @param  array<int, array{severity: string, confidence: float}>  $hazards
     * @param  array<int, string>  $statuses
     * @param  string  $worstRoadImpact  Passable|PartiallyBlocked|Blocked
     * @return float INF (PHP_INT_MAX) if blocked, else Base + hazardPenalty + uncertaintyPenalty
     */
    public function calculateSegmentCost(float $baseTravelCost, array $hazards, array $statuses, string $worstRoadImpact): float;
}
