<?php

declare(strict_types=1);

namespace App\Modules\Route\Services;

use App\Modules\Risk\Services\HazardPenaltyCalculator;
use App\Modules\Risk\Services\SegmentCostCalculator;
use App\Modules\Risk\Services\UncertaintyPenaltyCalculator;
use App\Modules\Routing\Services\RiskAwareRoutingService;
use App\Modules\Routing\Support\GraphBuilder;
use App\Modules\Shared\Support\SessionHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class RouteService
{
    public function __construct(
        private readonly GraphBuilder $graphBuilder,
        private readonly RiskAwareRoutingService $routingService,
        private readonly RouteGeometryService $geometryService,
    ) {}

    public function createRoute(Request $request, string $destinationId, array $origin): array
    {
        $dest = DB::table('destinations')->where('id', $destinationId)->first();
        if ($dest === null) {
            abort(404, 'Destination not found');
        }

        $originNode = $this->findNearestNode($origin);
        $destNode = $dest->nearest_road_node_id ?? $this->findNearestNodeFromGeom($dest->id);

        if ($originNode === null || $destNode === null) {
            abort(422, 'Origin or destination outside controlled network');
        }

        $graph = $this->graphBuilder->buildFromDatabase();
        $result = $this->routingService->findRouteOnGraph($originNode, $destNode, $graph);

        if (! $result['success']) {
            abort(409, 'No route available');
        }

        return DB::transaction(function () use ($request, $destinationId, $origin, $result) {
            $userId = SessionHelper::getOrCreateUserId($request);

            // Supersede active route - update old first to free partial unique index
            $active = null;
            if ($userId !== null) {
                $active = DB::table('routes')->where('user_id', $userId)->where('status', 'Active')->first();
                if ($active !== null) {
                    DB::table('routes')->where('id', $active->id)->update(['status' => 'Superseded', 'superseded_at' => now()]);
                }
            }

            $routeId = $this->insertRouteWithSegments($userId, $destinationId, $origin, $result, $active?->id);

            $segments = DB::table('route_segments')->where('route_id', $routeId)->orderBy('sequence_order')->get()->map(fn ($s) => [
                'road_segment_id' => $s->road_segment_id,
                'base_travel_cost' => (float) $s->base_travel_cost,
                'hazard_penalty' => (float) $s->hazard_penalty,
                'uncertainty_penalty' => (float) $s->uncertainty_penalty,
                'segment_routing_cost' => (float) $s->segment_routing_cost,
            ])->all();

            $geometry = $this->geometryService->getGeometry($routeId);

            return [
                'route_id' => $routeId,
                'destination_id' => $destinationId,
                'status' => 'Active',
                'supersedes_route_id' => $active?->id,
                'total_cost' => (float) $result['total_cost'],
                'segments' => $segments,
                'geometry' => $geometry,
                'created_at' => now()->toIso8601String(),
            ];
        });
    }

    /**
     * Persist a computed routing result as a route owned by no session user
     * (used by the Simulation module). Does not supersede any existing route.
     */
    public function persistSimulationRoute(string $destinationId, array $origin, array $result, array $excludeHazardIds = []): string
    {
        return DB::transaction(function () use ($destinationId, $origin, $result, $excludeHazardIds) {
            return $this->insertRouteWithSegments(null, $destinationId, $origin, $result, null, $excludeHazardIds);
        });
    }

    /**
     * Persist a replacement route for an existing user (hazard-driven
     * recalculation). The new route supersedes the given previous route.
     */
    public function persistReplacementRoute(string $userId, string $destinationId, array $origin, array $result, string $supersedesRouteId): string
    {
        return $this->insertRouteWithSegments($userId, $destinationId, $origin, $result, $supersedesRouteId);
    }

    public function persistSyntheticRoute(string $destinationId, array $origin, array $result, array $syntheticNodes): string
    {
        return DB::transaction(function () use ($destinationId, $origin, $result) {
            return $this->insertRouteWithSegments(null, $destinationId, $origin, $result, null);
        });
    }

    /**
     * Insert the routes row and its route_segments rows for a computed result.
     */
    private function insertRouteWithSegments(?string $userId, string $destinationId, array $origin, array $result, ?string $supersedesRouteId, array $excludeHazardIds = []): string
    {
        $routeId = (string) Str::uuid();
        DB::table('routes')->insert([
            'id' => $routeId,
            'user_id' => $userId,
            'destination_id' => $destinationId,
            'origin' => DB::raw("ST_GeogFromText('POINT({$origin['lng']} {$origin['lat']})')"),
            'status' => 'Active',
            'supersedes_route_id' => $supersedesRouteId,
            'total_cost' => $result['total_cost'],
            'created_at' => now(),
            'superseded_at' => null,
        ]);

        $this->insertRouteSegments($routeId, $result['road_segment_ids'], $excludeHazardIds);

        return $routeId;
    }

    private function insertRouteSegments(string $routeId, array $segmentIds, array $excludeHazardIds = []): void
    {
        $sequence = 0;
        foreach ($segmentIds as $segId) {
            $seg = DB::table('road_segments')->where('id', $segId)->first();
            if ($seg === null) continue;
            $q = DB::table('hazards')->where('road_segment_id', $segId);
            if ($excludeHazardIds !== []) {
                $q->whereNotIn('id', $excludeHazardIds);
            }
            $hazards = $q->get();
            $hazList = $hazards->map(fn ($h) => ['severity' => $h->severity, 'confidence' => (float) $h->confidence, 'roadImpact' => $h->road_impact, 'status' => $h->status])->all();
            $service = app(SegmentCostCalculator::class);
            $segmentCost = $service->calculate((float) $seg->base_travel_cost, $hazList);
            // Clamp blocked INF to max decimal to avoid numeric overflow; blocked segments should not be in a successful route.
            if ($segmentCost >= 1e10) {
                $segmentCost = 99999999.99;
            }
            $hazPenalty = app(HazardPenaltyCalculator::class)->calculateForSegment(array_map(fn ($h) => ['severity' => $h['severity'], 'confidence' => (float) $h['confidence']], $hazList));
            $uncPenalty = app(UncertaintyPenaltyCalculator::class)->calculateForSegment(array_column($hazList, 'status'));
            if ($hazPenalty >= 1e10) $hazPenalty = 99999999.99;
            if ($uncPenalty >= 1e10) $uncPenalty = 99999999.99;
            if ($segmentCost >= 1e10) $segmentCost = (float) $seg->base_travel_cost + $hazPenalty + $uncPenalty;
            if ($segmentCost >= 1e10) $segmentCost = 99999999.99;

            DB::table('route_segments')->insert([
                'id' => (string) Str::uuid(),
                'route_id' => $routeId,
                'road_segment_id' => $segId,
                'sequence_order' => $sequence++,
                'base_travel_cost' => $seg->base_travel_cost,
                'hazard_penalty' => $hazPenalty,
                'uncertainty_penalty' => $uncPenalty,
                'segment_routing_cost' => $segmentCost,
            ]);
        }
    }

    public function getRoute(string $routeId): array
    {
        $route = DB::table('routes')->where('id', $routeId)->first();
        if ($route === null) {
            abort(404, 'Route not found');
        }
        $segments = DB::table('route_segments')->where('route_id', $routeId)->orderBy('sequence_order')->get()->map(fn ($s) => [
            'road_segment_id' => $s->road_segment_id,
            'base_travel_cost' => (float) $s->base_travel_cost,
            'hazard_penalty' => (float) $s->hazard_penalty,
            'uncertainty_penalty' => (float) $s->uncertainty_penalty,
            'segment_routing_cost' => (float) $s->segment_routing_cost,
        ])->all();

        $originLoc = DB::selectOne('SELECT ST_X(origin::geometry) as lng, ST_Y(origin::geometry) as lat FROM routes WHERE id = ?', [$routeId]);
        $supersededBy = DB::table('routes')->where('supersedes_route_id', $routeId)->first();
        $geometry = $this->geometryService->getGeometry($routeId);

        return [
            'route_id' => $route->id,
            'destination_id' => $route->destination_id,
            'status' => $route->status,
            'supersedes_route_id' => $route->supersedes_route_id,
            'superseded_by_route_id' => $supersededBy?->id,
            'total_cost' => (float) $route->total_cost,
            'segments' => $segments,
            'geometry' => $geometry,
            'created_at' => $route->created_at,
        ];
    }

    public function getActiveRoute(Request $request): array
    {
        $userId = SessionHelper::getUserIdFromHeader($request);
        if ($userId === null) {
            abort(404, 'No active route');
        }
        $route = DB::table('routes')->where('user_id', $userId)->where('status', 'Active')->first();
        if ($route === null) {
            abort(404, 'No active route');
        }

        return $this->getRoute($route->id);
    }

    public function findNearestNode(array $location): ?string
    {
        $lng = $location['lng'];
        $lat = $location['lat'];
        $row = DB::selectOne("SELECT id FROM road_nodes WHERE is_synthetic = false ORDER BY geom <-> ST_GeogFromText('POINT($lng $lat)') LIMIT 1");

        return $row?->id;
    }

    public function findNearestNodeFromGeom(string $destinationId): ?string
    {
        $row = DB::selectOne('SELECT nearest_road_node_id as id FROM destinations WHERE id = ?', [$destinationId]);
        if ($row?->id !== null) {
            return $row->id;
        }
        $destLoc = DB::selectOne('SELECT ST_X(geom::geometry) as lng, ST_Y(geom::geometry) as lat FROM destinations WHERE id = ?', [$destinationId]);
        if ($destLoc === null) {
            return null;
        }

        return $this->findNearestNode(['lng' => (float) $destLoc->lng, 'lat' => (float) $destLoc->lat]);
    }
}
