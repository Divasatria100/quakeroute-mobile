<?php

declare(strict_types=1);

namespace App\Modules\Routing\Support;

use App\Modules\Risk\Services\SegmentCostCalculator;
use Illuminate\Support\Facades\DB;

final class GraphBuilder
{
    public function __construct(
        private readonly SegmentCostCalculator $segmentCostCalculator,
    ) {}

    /**
     * Build adjacency list from database.
     *
     * @return array<string, array<int, array{to: string, cost: float, road_segment_id: string}>>
     */
    public function buildFromDatabase(): array
    {
        $nodes = DB::table('road_nodes')->pluck('id')->all();
        $segments = DB::table('road_segments')->get();
        $hazards = DB::table('hazards')
            ->select('road_segment_id', 'severity', 'confidence', 'road_impact', 'status')
            ->whereNotNull('road_segment_id')
            ->get()
            ->groupBy('road_segment_id');

        $list = [];
        foreach ($segments as $seg) {
            $segHazards = isset($hazards[$seg->id]) ? $hazards[$seg->id]->map(fn ($h) => [
                'severity' => $h->severity,
                'confidence' => (float) $h->confidence,
                'roadImpact' => $h->road_impact,
                'status' => $h->status,
            ])->all() : [];

            $list[] = [
                'id' => $seg->id,
                'from_node_id' => $seg->from_node_id,
                'to_node_id' => $seg->to_node_id,
                'base_travel_cost' => (float) $seg->base_travel_cost,
                'bidirectional' => (bool) $seg->bidirectional,
                'hazards' => $segHazards,
            ];
        }

        return $this->build($nodes, $list);
    }

    /**
     * Build adjacency list from arrays (test-friendly).
     *
     * @param  array<int, string>  $nodeIds
     * @param  array<int, array{id: string, from_node_id: string, to_node_id: string, base_travel_cost: float, bidirectional: bool, hazards: array<int, array{severity: string, confidence: float, roadImpact: string, status: string}>}>  $segments
     * @return array<string, array<int, array{to: string, cost: float, road_segment_id: string}>>
     */
    public function build(array $nodeIds, array $segments): array
    {
        $graph = [];
        foreach ($nodeIds as $nid) {
            $graph[$nid] = [];
        }

        $blockedCost = (float) config('risk.blocked_cost', PHP_INT_MAX);

        foreach ($segments as $seg) {
            $cost = $this->segmentCostCalculator->calculate((float) $seg['base_travel_cost'], $seg['hazards']);

            if ($cost >= $blockedCost) {
                continue; // excluded
            }

            $graph[$seg['from_node_id']][] = [
                'to' => $seg['to_node_id'],
                'cost' => $cost,
                'road_segment_id' => $seg['id'],
            ];

            if ($seg['bidirectional']) {
                $graph[$seg['to_node_id']][] = [
                    'to' => $seg['from_node_id'],
                    'cost' => $cost,
                    'road_segment_id' => $seg['id'],
                ];
            }
        }

        return $graph;
    }
}
