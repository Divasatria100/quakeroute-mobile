<?php

declare(strict_types=1);

namespace App\Modules\Routing\Contracts;

interface RoutingEngineInterface
{
    /**
     * Find risk-aware route.
     *
     * @return array{success: bool, total_cost: ?float, node_ids: array<int, string>, road_segment_ids: array<int, string>, reason: ?string}
     */
    public function findRoute(string $originNodeId, string $destinationNodeId): array;
}
