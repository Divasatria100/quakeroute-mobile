<?php

declare(strict_types=1);

namespace App\Modules\Simulation\Services;

use App\Modules\Route\Services\RouteService;
use App\Modules\Routing\Services\RiskAwareRoutingService;
use App\Modules\Routing\Support\GraphBuilder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class SimulationService
{
    protected const ALLOWED_TYPES = ['DebrisRubble', 'RoadBlockage', 'Fire', 'Flood', 'ElectricalHazard', 'VisibleBuildingDamage'];

    public function __construct(
        private readonly RouteService $routeService,
        private readonly GraphBuilder $graphBuilder,
        private readonly RiskAwareRoutingService $routingService,
    ) {}

    public function listScenarios(): array
    {
        return DB::table('simulation_scenarios')->orderBy('scenario_key')->get()->map(fn ($r) => [
            'scenario_id' => $r->scenario_key,
            'name' => $r->name,
        ])->all();
    }

    public function runScenario(string $scenarioId, array $origin, string $destinationId): array
    {
        $scenario = DB::table('simulation_scenarios')->where('scenario_key', $scenarioId)->first();
        if ($scenario === null) {
            abort(404, 'Scenario not found');
        }
        $dest = DB::table('destinations')->where('id', $destinationId)->first();
        if ($dest === null) {
            abort(422, 'Destination not found');
        }

        $originNode = $this->routeService->findNearestNode($origin);
        $destNode = $dest->nearest_road_node_id ?? $this->routeService->findNearestNodeFromGeom($dest->id);
        if ($originNode === null || $destNode === null) {
            abort(422, 'Origin or destination outside controlled network');
        }

        $runId = (string) Str::uuid();
        DB::table('simulation_runs')->insert([
            'id' => $runId,
            'scenario_key' => $scenarioId,
            'origin' => DB::raw("ST_GeogFromText('POINT({$origin['lng']} {$origin['lat']})')"),
            'destination_id' => $destinationId,
            'status' => 'Running',
            'baseline_route_id' => null,
            'risk_aware_route_id' => null,
            'started_at' => now(),
            'completed_at' => null,
        ]);

        // 1) Inject deterministic simulated hazards linked to this run.
        $injected = json_decode((string) $scenario->injected_observations, true) ?? [];
        [$hazardRecords, $hazardIds] = $this->createHazards($runId, $injected);

        // 2) Baseline graph: exclude exactly the injected simulation hazards so it
        //    reflects normal network costs.
        $baselineGraph = $this->graphBuilder->buildFromDatabase($hazardIds);
        $baseline = $this->routingService->findRouteOnGraph($originNode, $destNode, $baselineGraph);

        // 3) Risk-aware graph: includes injected hazards -> risk-adjusted costs.
        $riskGraph = $this->graphBuilder->buildFromDatabase();
        $riskAware = $this->routingService->findRouteOnGraph($originNode, $destNode, $riskGraph);

        // 4) Persist both routes (owned by no session user).
        $baselineRouteId = null;
        $riskAwareRouteId = null;

        if ($baseline['success']) {
            $baselineRouteId = $this->routeService->persistSimulationRoute($destinationId, $origin, $baseline, $hazardIds);
        }

        if ($riskAware['success']) {
            $riskAwareRouteId = $this->routeService->persistSimulationRoute($destinationId, $origin, $riskAware);
        }

        // 5) Link injected hazards to the run and finalize it.
        foreach ($hazardIds as $hid) {
            DB::table('simulation_run_hazards')->insertOrIgnore([
                'id' => (string) Str::uuid(),
                'simulation_run_id' => $runId,
                'hazard_id' => $hid,
            ]);
        }

        DB::table('simulation_runs')->where('id', $runId)->update([
            'status' => 'Completed',
            'baseline_route_id' => $baselineRouteId,
            'risk_aware_route_id' => $riskAwareRouteId,
            'completed_at' => now(),
        ]);

        return [
            'run_id' => $runId,
            'scenario_id' => $scenarioId,
            'status' => 'Completed',
            'started_at' => now()->toIso8601String(),
            'baseline_route_id' => $baselineRouteId,
            'risk_aware_route_id' => $riskAwareRouteId,
            'baseline_cost' => $baseline['success'] ? (float) $baseline['total_cost'] : null,
            'risk_aware_cost' => $riskAware['success'] ? (float) $riskAware['total_cost'] : null,
            'hazards_created' => $hazardRecords,
        ];
    }

    /**
     * Create simulated hazards (records in hazards table) linked to the run.
     *
     * @param  array<int, mixed>  $injected
     * @return array{0: array<int, array<string, mixed>>, 1: array<int, string>}
     */
    private function createHazards(string $runId, array $injected): array
    {
        $records = [];
        $ids = [];
        foreach ($injected as $obs) {
            if (! is_array($obs) || ! isset($obs['road_segment_id'])) {
                continue;
            }

            $type = $obs['type'] ?? 'DebrisRubble';
            if (! in_array($type, self::ALLOWED_TYPES, true)) {
                continue;
            }

            $location = $this->resolveHazardLocation($obs['road_segment_id'], $obs['location'] ?? null);
            if ($location === null) {
                continue;
            }

            $hazardId = (string) Str::uuid();
            $severity = $obs['severity'] ?? 'Medium';
            $roadImpact = $obs['road_impact'] ?? 'PartiallyBlocked';
            $confidence = (float) ($obs['confidence'] ?? 0.9);
            $status = $obs['status'] ?? 'Confirmed';

            DB::table('hazards')->insert([
                'id' => $hazardId,
                'hazard_report_id' => null,
                'hazard_suggestion_id' => null,
                'type' => $type,
                'severity' => $severity,
                'confidence' => $confidence,
                'road_impact' => $roadImpact,
                'status' => $status,
                'source' => 'AITextExtraction',
                'road_segment_id' => $obs['road_segment_id'],
                'evidence_photo_url' => null,
                'evidence_text' => null,
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'reported_at' => now(),
                'updated_at' => now(),
            ]);

            $ids[] = $hazardId;
            $records[] = [
                'hazard_id' => $hazardId,
                'type' => $type,
                'severity' => $severity,
                'confidence' => $confidence,
                'road_impact' => $roadImpact,
                'road_segment_id' => $obs['road_segment_id'],
            ];
        }

        return [$records, $ids];
    }

    private function resolveHazardLocation(string $segmentId, ?array $location): ?array
    {
        if (is_array($location) && isset($location['lat'], $location['lng'])) {
            return ['lat' => (float) $location['lat'], 'lng' => (float) $location['lng']];
        }

        $row = DB::selectOne('SELECT ST_X(ST_Centroid(geom::geometry)) as lng, ST_Y(ST_Centroid(geom::geometry)) as lat FROM road_segments WHERE id = ?', [$segmentId]);

        return $row === null ? null : ['lat' => (float) $row->lat, 'lng' => (float) $row->lng];
    }

    public function getRun(string $runId): array
    {
        $run = DB::table('simulation_runs')->where('id', $runId)->first();
        if ($run === null) {
            abort(404, 'Run not found');
        }

        $hazards = DB::table('simulation_run_hazards')
            ->where('simulation_run_id', $runId)
            ->join('hazards', 'hazards.id', '=', 'simulation_run_hazards.hazard_id')
            ->get()
            ->map(fn ($r) => [
                'hazard_id' => $r->hazard_id,
                'type' => $r->type,
                'road_impact' => $r->road_impact,
                'severity' => $r->severity,
                'road_segment_id' => $r->road_segment_id,
            ])->all();

        $originLoc = DB::selectOne('SELECT ST_X(origin::geometry) as lng, ST_Y(origin::geometry) as lat FROM simulation_runs WHERE id = ?', [$runId]);

        return [
            'run_id' => $run->id,
            'scenario_id' => $run->scenario_key,
            'status' => $run->status,
            'origin' => $originLoc ? ['lat' => (float) $originLoc->lat, 'lng' => (float) $originLoc->lng] : null,
            'hazards_created' => $hazards,
            'baseline_route' => $run->baseline_route_id ? $this->routeSummary($run->baseline_route_id) : null,
            'risk_aware_route' => $run->risk_aware_route_id ? $this->routeSummary($run->risk_aware_route_id) : null,
            'completed_at' => $run->completed_at,
        ];
    }

    private function routeSummary(string $routeId): array
    {
        $route = DB::table('routes')->where('id', $routeId)->first();
        if ($route === null) {
            return ['route_id' => $routeId, 'total_cost' => 0, 'segments' => []];
        }
        $segments = DB::table('route_segments as rs')
            ->join('road_segments as seg', 'seg.id', '=', 'rs.road_segment_id')
            ->where('rs.route_id', $routeId)
            ->orderBy('rs.sequence_order')
            ->get()
            ->map(fn ($s) => [
                'road_segment_id' => $s->road_segment_id,
                'from_node_id' => $s->from_node_id,
                'to_node_id' => $s->to_node_id,
            ])->all();

        return [
            'route_id' => $routeId,
            'status' => $route->status,
            'total_cost' => (float) $route->total_cost,
            'segments' => $segments,
        ];
    }
}