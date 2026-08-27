<?php

declare(strict_types=1);

namespace App\Modules\Route\Services;

use App\Modules\Routing\Services\RiskAwareRoutingService;
use App\Modules\Routing\Support\GraphBuilder;
use Illuminate\Support\Facades\DB;

final class RouteRecalculationService
{
    public function __construct(
        private readonly GraphBuilder $graphBuilder,
        private readonly RiskAwareRoutingService $routingService,
        private readonly RouteService $routeService,
    ) {}

    /**
     * Recalculate any Active user-owned routes that contain the given affected
     * road segment. Routes that do not use the segment are left untouched.
     */
    public function recalculateForAffectedSegment(string $roadSegmentId): void
    {
        $affectedUserIds = DB::table('route_segments as rs')
            ->join('routes as r', 'r.id', '=', 'rs.route_id')
            ->where('rs.road_segment_id', $roadSegmentId)
            ->where('r.status', 'Active')
            ->whereNotNull('r.user_id')
            ->distinct()
            ->pluck('r.user_id');

        foreach ($affectedUserIds as $userId) {
            $this->recalculateForUser((string) $userId);
        }
    }

    private function recalculateForUser(string $userId): void
    {
        $current = DB::table('routes')
            ->where('user_id', $userId)
            ->where('status', 'Active')
            ->first();

        if ($current === null) {
            return;
        }

        $origin = $this->readOrigin($current->id);
        if ($origin === null) {
            return;
        }

        $dest = DB::table('destinations')->where('id', $current->destination_id)->first();
        if ($dest === null) {
            return;
        }

        $originNode = $this->routeService->findNearestNode($origin);
        $destNode = $dest->nearest_road_node_id ?? $this->routeService->findNearestNodeFromGeom($dest->id);
        if ($originNode === null || $destNode === null) {
            return;
        }

        $graph = $this->graphBuilder->buildFromDatabase();
        $result = $this->routingService->findRouteOnGraph($originNode, $destNode, $graph);

        DB::transaction(function () use ($current, $origin, $userId, $result) {
            // Mark the current active route superseded first (frees the unique
            // per-user active index before inserting the replacement).
            DB::table('routes')->where('id', $current->id)
                ->update(['status' => 'Superseded', 'superseded_at' => now()]);

            if (! $result['success']) {
                // Affected segment now blocks every path; the route is superseded
                // and no replacement is produced.
                return;
            }

            $this->routeService->persistReplacementRoute(
                $userId,
                $current->destination_id,
                $origin,
                $result,
                $current->id
            );
        });
    }

    private function readOrigin(string $routeId): ?array
    {
        $row = DB::selectOne('SELECT ST_X(origin::geometry) as lng, ST_Y(origin::geometry) as lat FROM routes WHERE id = ?', [$routeId]);
        if ($row === null) {
            return null;
        }

        return ['lat' => (float) $row->lat, 'lng' => (float) $row->lng];
    }
}
