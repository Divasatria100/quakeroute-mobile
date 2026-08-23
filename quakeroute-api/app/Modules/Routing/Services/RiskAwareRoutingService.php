<?php

declare(strict_types=1);

namespace App\Modules\Routing\Services;

use App\Modules\Routing\Contracts\RoutingEngineInterface;
use App\Modules\Routing\Support\GraphBuilder;

final class RiskAwareRoutingService implements RoutingEngineInterface
{
    public function __construct(
        private readonly GraphBuilder $graphBuilder,
    ) {}

    public function findRoute(string $originNodeId, string $destinationNodeId): array
    {
        $graph = $this->graphBuilder->buildFromDatabase();

        return $this->findRouteOnGraph($originNodeId, $destinationNodeId, $graph);
    }

    /**
     * Dijkstra on in-memory graph.
     *
     * @param  array<string, array<int, array{to: string, cost: float, road_segment_id: string}>>  $graph
     * @return array{success: bool, total_cost: ?float, node_ids: array<int, string>, road_segment_ids: array<int, string>, reason: ?string}
     */
    public function findRouteOnGraph(string $origin, string $destination, array $graph): array
    {
        if (! isset($graph[$origin]) || ! isset($graph[$destination])) {
            return ['success' => false, 'total_cost' => null, 'node_ids' => [], 'road_segment_ids' => [], 'reason' => 'NO_ROUTE'];
        }

        if ($origin === $destination) {
            return ['success' => true, 'total_cost' => 0.0, 'node_ids' => [$origin], 'road_segment_ids' => [], 'reason' => null];
        }

        $dist = [];
        $prevNode = [];
        $prevEdge = [];
        $visited = [];

        foreach (array_keys($graph) as $node) {
            $dist[$node] = INF;
        }
        $dist[$origin] = 0.0;

        // Simple priority queue via array + min search (graph small for MVP)
        $queue = [$origin];

        while ($queue !== []) {
            // Find node with min dist in queue
            $u = null;
            $min = INF;
            foreach ($queue as $candidate) {
                if ($dist[$candidate] < $min) {
                    $min = $dist[$candidate];
                    $u = $candidate;
                }
            }
            if ($u === null) {
                break;
            }
            $queue = array_values(array_filter($queue, fn ($n) => $n !== $u));
            if (isset($visited[$u])) {
                continue;
            }
            $visited[$u] = true;

            if ($u === $destination) {
                break;
            }

            foreach ($graph[$u] ?? [] as $edge) {
                $v = $edge['to'];
                $cost = (float) $edge['cost'];
                $alt = $dist[$u] + $cost;
                if ($alt < ($dist[$v] ?? INF)) {
                    $dist[$v] = $alt;
                    $prevNode[$v] = $u;
                    $prevEdge[$v] = $edge['road_segment_id'];
                    if (! in_array($v, $queue, true) && ! isset($visited[$v])) {
                        $queue[] = $v;
                    } elseif (! in_array($v, $queue, true)) {
                        $queue[] = $v;
                    }
                }
            }
        }

        if (! isset($dist[$destination]) || $dist[$destination] === INF) {
            return ['success' => false, 'total_cost' => null, 'node_ids' => [], 'road_segment_ids' => [], 'reason' => 'NO_ROUTE'];
        }

        // Reconstruct path
        $nodeIds = [];
        $segmentIds = [];
        $cur = $destination;
        while ($cur !== null) {
            $nodeIds[] = $cur;
            if (isset($prevEdge[$cur])) {
                $segmentIds[] = $prevEdge[$cur];
            }
            $cur = $prevNode[$cur] ?? null;
            if ($cur === $origin) {
                $nodeIds[] = $cur;
                break;
            }
        }
        $nodeIds = array_reverse($nodeIds);
        $segmentIds = array_reverse($segmentIds);

        return [
            'success' => true,
            'total_cost' => $dist[$destination],
            'node_ids' => $nodeIds,
            'road_segment_ids' => $segmentIds,
            'reason' => null,
        ];
    }
}
