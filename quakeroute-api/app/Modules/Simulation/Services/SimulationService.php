<?php

declare(strict_types=1);

namespace App\Modules\Simulation\Services;

use App\Modules\Route\Services\RouteService;
use App\Modules\Routing\Services\RiskAwareRoutingService;
use App\Modules\Routing\Support\GraphBuilder;
use App\Modules\Simulation\Support\SyntheticNetworkGenerator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Random\Engine\Mt19937;
use Random\Randomizer;

final class SimulationService
{
    protected const ALLOWED_TYPES = ['DebrisRubble', 'RoadBlockage', 'Fire', 'Flood', 'ElectricalHazard', 'VisibleBuildingDamage'];

    public function __construct(
        private readonly RouteService $routeService,
        private readonly GraphBuilder $graphBuilder,
        private readonly RiskAwareRoutingService $routingService,
        private readonly SyntheticNetworkGenerator $syntheticGenerator,
    ) {}

    public function listScenarios(): array
    {
        return DB::table('simulation_scenarios')->orderBy('scenario_key')->get()->map(fn ($r) => [
            'scenario_id' => $r->scenario_key,
            'name' => $r->name,
        ])->all();
    }

    public function runScenario(string $scenarioId, array $origin, string $destinationId, ?array $center = null, ?int $seed = null, ?int $radiusM = null): array
    {
        $scenario = DB::table('simulation_scenarios')->where('scenario_key', $scenarioId)->first();
        if ($scenario === null) {
            abort(404, 'Scenario not found');
        }

        // Synthetic mode when center is provided (crosshair).
        if ($center !== null && isset($center['lat'], $center['lng'])) {
            return $this->runSyntheticScenario($scenarioId, $scenario, $center, $destinationId, $seed ?? random_int(1, 999999), $radiusM ?? 1500, $origin);
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
     * Synthetic mode: generate network around center deterministically.
     */
    private function runSyntheticScenario(string $scenarioId, object $scenario, array $center, string $destinationId, int $seed, int $radiusM, array $origin): array
    {
        $centerLat = (float) $center['lat'];
        $centerLng = (float) $center['lng'];

        // Generate synthetic network around center.
        $generated = $this->syntheticGenerator->generate($centerLat, $centerLng, $seed, $radiusM);
        $nodes = $generated['nodes'];
        $segments = $generated['segments'];
        $syntheticDests = $generated['destinations'];

        $runId = (string) Str::uuid();

        // Insert synthetic nodes/segments with is_synthetic flag for geometry persistence (idempotent for same seed+center).
        foreach ($nodes as $n) {
            DB::table('road_nodes')->updateOrInsert(['id' => $n['id']], [
                'label' => $n['label'],
                'geom' => DB::raw("ST_GeogFromText('POINT({$n['lng']} {$n['lat']})')"),
                'is_synthetic' => true,
                'simulation_run_id' => $runId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        foreach ($segments as $s) {
            DB::table('road_segments')->updateOrInsert(['id' => $s['id']], [
                'from_node_id' => $s['from'],
                'to_node_id' => $s['to'],
                'geom' => DB::raw("ST_GeogFromText('{$s['wkt']}')"),
                'base_travel_cost' => $s['base_cost'],
                'bidirectional' => $s['bidirectional'],
                'is_synthetic' => true,
                'simulation_run_id' => $runId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        foreach ($syntheticDests as $d) {
            DB::table('destinations')->updateOrInsert(['id' => $d['id']], [
                'name' => $d['name'],
                'type' => $d['type'],
                'geom' => DB::raw("ST_GeogFromText('POINT({$d['lng']} {$d['lat']})')"),
                'nearest_road_node_id' => $nodes[5]['id'] ?? $nodes[0]['id'],
                'is_synthetic' => true,
                'simulation_run_id' => $runId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        // Match selected synthetic destination or fall back to first
        $chosenDest = null;
        foreach ($syntheticDests as $d) {
            if ($d['id'] === $destinationId) {
                $chosenDest = $d;
                break;
            }
        }
        if ($chosenDest === null) {
            $chosenDest = $syntheticDests[0];
        }
        $destIdForRun = $chosenDest['id'];

        $originNode = $this->findNearestSyntheticNode($centerLat, $centerLng, $nodes);
        $destNode = $this->findNearestSyntheticNode($chosenDest['lat'], $chosenDest['lng'], $nodes);

        DB::table('simulation_runs')->insert([
            'id' => $runId,
            'scenario_key' => $scenarioId,
            'origin' => DB::raw("ST_GeogFromText('POINT({$centerLng} {$centerLat})')"),
            'destination_id' => $destIdForRun,
            'status' => 'Running',
            'baseline_route_id' => null,
            'risk_aware_route_id' => null,
            'started_at' => now(),
            'completed_at' => null,
        ]);

        // Compute initial clean baseline path to target hazard placement on actual baseline path
        $nodeIds = array_column($nodes, 'id');
        $cleanSegmentsForGraph = $this->segmentsWithHazardsForGraph($segments, [], []);
        $cleanGraph = $this->graphBuilder->build($nodeIds, $cleanSegmentsForGraph);
        $initialBaseline = $this->routingService->findRouteOnGraph($originNode, $destNode, $cleanGraph);
        $baselinePathSegments = $initialBaseline['success'] ? $initialBaseline['road_segment_ids'] : [];

        // Generate scenario-specific hazards targeting baseline path segments
        [$hazardRecords, $hazardIds] = $this->createSyntheticHazards($runId, $scenarioId, $segments, $seed, $baselinePathSegments);

        // Build graphs in-memory from synthetic network.
        $baselineSegments = $this->segmentsWithHazardsForGraph($segments, [], $hazardIds);
        $riskSegments = $this->segmentsWithHazardsForGraph($segments, $this->hazardsForGraph($hazardIds), []);

        $baselineGraph = $this->graphBuilder->build($nodeIds, $baselineSegments);
        $riskGraph = $this->graphBuilder->build($nodeIds, $riskSegments);

        $baseline = $this->routingService->findRouteOnGraph($originNode, $destNode, $baselineGraph);
        $riskAware = $this->routingService->findRouteOnGraph($originNode, $destNode, $riskGraph);

        $baselineRouteId = null;
        $riskAwareRouteId = null;
        if ($baseline['success']) {
            $baselineRouteId = $this->routeService->persistSimulationRoute($destIdForRun, ['lat' => $centerLat, 'lng' => $centerLng], $baseline, $hazardIds);
        }
        if ($riskAware['success']) {
            $riskAwareRouteId = $this->routeService->persistSimulationRoute($destIdForRun, ['lat' => $centerLat, 'lng' => $centerLng], $riskAware);
        }

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
            'center' => $center,
            'seed' => $seed,
            'synthetic_destinations' => $syntheticDests,
            'network' => [
                'nodes' => array_map(fn ($n) => ['id' => $n['id'], 'lat' => $n['lat'], 'lng' => $n['lng'], 'label' => $n['label']], $nodes),
                'segments' => array_map(fn ($s) => ['id' => $s['id'], 'from' => $s['from'], 'to' => $s['to'], 'wkt' => $s['wkt']], $segments),
            ],
        ];
    }

    private function findNearestSyntheticNode(float $lat, float $lng, array $nodes): string
    {
        $best = $nodes[0]['id'];
        $bestDist = PHP_INT_MAX;
        foreach ($nodes as $n) {
            $dLat = $n['lat'] - $lat;
            $dLng = $n['lng'] - $lng;
            $dist = $dLat * $dLat + $dLng * $dLng;
            if ($dist < $bestDist) {
                $bestDist = $dist;
                $best = $n['id'];
            }
        }

        return $best;
    }

    private function createSyntheticHazards(string $runId, string $scenarioId, array $segments, int $seed, array $preferredSegmentIds = []): array
    {
        $rand = new Randomizer(new Mt19937($seed + crc32($scenarioId)));
        $records = [];
        $ids = [];

        $candidateSegments = array_values(array_filter($segments, fn ($s) => in_array($s['id'], $preferredSegmentIds, true)));
        if (empty($candidateSegments)) {
            $candidateSegments = $segments;
        }

        $pickSegment = function () use ($candidateSegments, $rand): array {
            $idx = $rand->getInt(0, count($candidateSegments) - 1);

            return $candidateSegments[$idx];
        };

        $makeHazard = function (array $seg, string $type, string $severity, string $roadImpact, float $conf, string $status) use (&$records, &$ids) {
            $hid = (string) Str::uuid();
            $coords = DB::selectOne('SELECT ST_X(ST_Centroid(geom::geometry)) as lng, ST_Y(ST_Centroid(geom::geometry)) as lat FROM road_segments WHERE id = ?', [$seg['id']]);
            $lat = $coords ? (float) $coords->lat : 0;
            $lng = $coords ? (float) $coords->lng : 0;

            DB::table('hazards')->insert([
                'id' => $hid,
                'type' => $type,
                'severity' => $severity,
                'confidence' => $conf,
                'road_impact' => $roadImpact,
                'status' => $status,
                'source' => 'AITextExtraction',
                'road_segment_id' => $seg['id'],
                'location' => DB::raw("ST_GeogFromText('POINT({$lng} {$lat})')"),
                'reported_at' => now(),
                'updated_at' => now(),
            ]);
            $ids[] = $hid;
            $records[] = ['hazard_id' => $hid, 'type' => $type, 'severity' => $severity, 'confidence' => $conf, 'road_impact' => $roadImpact, 'road_segment_id' => $seg['id'], 'status' => $status, 'location' => ['lat' => $lat, 'lng' => $lng]];
        };

        if ($scenarioId === 'no_hazard') {
            return [[], []];
        } elseif ($scenarioId === 'blocked_road' || $scenarioId === 'new_hazard_during_navigation') {
            $seg = $pickSegment();
            $makeHazard($seg, 'RoadBlockage', 'High', 'Blocked', 0.95, 'Confirmed');
        } elseif ($scenarioId === 'high_risk_hazard') {
            $seg = $pickSegment();
            $makeHazard($seg, 'Fire', 'High', 'PartiallyBlocked', 0.9, 'Confirmed');
        } elseif ($scenarioId === 'conflicting_reports') {
            $seg = $pickSegment();
            $makeHazard($seg, 'Flood', 'High', 'Blocked', 0.8, 'Confirmed');
            $makeHazard($seg, 'Flood', 'Low', 'Passable', 0.6, 'UncertainConflicting');
        } elseif ($scenarioId === 'ai_vision_hazard_report') {
            $seg = $pickSegment();
            $makeHazard($seg, 'VisibleBuildingDamage', 'Medium', 'PartiallyBlocked', 0.75, 'Reported');
        } else {
            $seg = $pickSegment();
            $makeHazard($seg, 'DebrisRubble', 'Medium', 'PartiallyBlocked', 0.7, 'Reported');
        }

        return [$records, $ids];
    }

    private function segmentsWithHazardsForGraph(array $segments, array $hazardsBySegment, array $excludeIds): array
    {
        $result = [];
        foreach ($segments as $seg) {
            $result[] = [
                'id' => $seg['id'],
                'from_node_id' => $seg['from'],
                'to_node_id' => $seg['to'],
                'base_travel_cost' => $seg['base_cost'],
                'bidirectional' => $seg['bidirectional'],
                'hazards' => $hazardsBySegment[$seg['id']] ?? [],
            ];
        }

        return $result;
    }

    private function hazardsForGraph(array $hazardIds): array
    {
        if ($hazardIds === []) {
            return [];
        }
        $rows = DB::table('hazards')->whereIn('id', $hazardIds)->get();
        $grouped = [];
        foreach ($rows as $r) {
            $grouped[$r->road_segment_id][] = [
                'severity' => $r->severity,
                'confidence' => (float) $r->confidence,
                'roadImpact' => $r->road_impact,
                'status' => $r->status,
            ];
        }

        return $grouped;
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
            ->selectRaw('hazards.*, ST_X(hazards.location::geometry) as lng, ST_Y(hazards.location::geometry) as lat')
            ->get()
            ->map(fn ($r) => [
                'hazard_id' => $r->id,
                'type' => $r->type,
                'road_impact' => $r->road_impact,
                'severity' => $r->severity,
                'confidence' => (float) $r->confidence,
                'status' => $r->status,
                'road_segment_id' => $r->road_segment_id,
                'location' => ['lat' => (float) $r->lat, 'lng' => (float) $r->lng],
            ])->all();

        $originLoc = DB::selectOne('SELECT ST_X(origin::geometry) as lng, ST_Y(origin::geometry) as lat FROM simulation_runs WHERE id = ?', [$runId]);

        $syntheticDests = DB::table('destinations')
            ->where('simulation_run_id', $runId)
            ->selectRaw('id, name, type, ST_X(geom::geometry) as lng, ST_Y(geom::geometry) as lat')
            ->get()
            ->map(fn ($d) => [
                'id' => $d->id,
                'name' => $d->name,
                'type' => $d->type,
                'lat' => (float) $d->lat,
                'lng' => (float) $d->lng,
            ])->all();

        $syntheticSegments = DB::table('road_segments')
            ->where('simulation_run_id', $runId)
            ->selectRaw('id, from_node_id as "from", to_node_id as "to", ST_AsText(geom::geometry) as wkt')
            ->get()
            ->map(fn ($s) => [
                'id' => $s->id,
                'from' => $s->from,
                'to' => $s->to,
                'wkt' => $s->wkt,
            ])->all();

        $syntheticNodes = DB::table('road_nodes')
            ->where('simulation_run_id', $runId)
            ->selectRaw('id, label, ST_X(geom::geometry) as lng, ST_Y(geom::geometry) as lat')
            ->get()
            ->map(fn ($n) => [
                'id' => $n->id,
                'label' => $n->label,
                'lat' => (float) $n->lat,
                'lng' => (float) $n->lng,
            ])->all();

        $res = [
            'run_id' => $run->id,
            'scenario_id' => $run->scenario_key,
            'status' => $run->status,
            'origin' => $originLoc ? ['lat' => (float) $originLoc->lat, 'lng' => (float) $originLoc->lng] : null,
            'hazards_created' => $hazards,
            'baseline_route' => $run->baseline_route_id ? $this->routeSummary($run->baseline_route_id) : null,
            'risk_aware_route' => $run->risk_aware_route_id ? $this->routeSummary($run->risk_aware_route_id) : null,
            'completed_at' => $run->completed_at,
        ];

        if (! empty($syntheticDests)) {
            $res['synthetic_destinations'] = $syntheticDests;
        }
        if (! empty($syntheticNodes) || ! empty($syntheticSegments)) {
            $res['network'] = [
                'nodes' => $syntheticNodes,
                'segments' => $syntheticSegments,
            ];
        }

        return $res;
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
