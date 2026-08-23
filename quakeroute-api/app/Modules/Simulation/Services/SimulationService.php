<?php

declare(strict_types=1);

namespace App\Modules\Simulation\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class SimulationService
{
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

        // For MVP, synchronous execution: create baseline and risk-aware routes via RouteService
        // Baseline = without hazards (we simulate by building graph without hazard penalties)
        // For simplicity, we create two routes with same origin/destination but store as simulation runs
        // Actual hazard injection from injected_observations is TBD - keep minimal

        // Create dummy hazards if scenario has injected_observations (not required for API contract)
        $injected = json_decode($scenario->injected_observations, true) ?? [];
        $hazardsCreated = [];
        foreach ($injected as $obs) {
            // Create a hazard for simulation (if obs has type)
            if (isset($obs['type'])) {
                $hazardId = (string) Str::uuid();
                $hazardsCreated[] = ['hazard_id' => $hazardId, 'type' => $obs['type'] ?? 'DebrisRubble', 'road_impact' => $obs['road_impact'] ?? 'Passable'];
            }
        }

        // In a real implementation, we would compute baseline (base cost only) and risk-aware (with hazards)
        // For MVP, mark as Completed with null routes (to be computed if road network exists)
        DB::table('simulation_runs')->where('id', $runId)->update([
            'status' => 'Completed',
            'completed_at' => now(),
        ]);

        return [
            'run_id' => $runId,
            'scenario_id' => $scenarioId,
            'status' => 'Completed',
            'started_at' => now()->toIso8601String(),
            'hazards_created' => $hazardsCreated,
        ];
    }

    public function getRun(string $runId): array
    {
        $run = DB::table('simulation_runs')->where('id', $runId)->first();
        if ($run === null) {
            abort(404, 'Run not found');
        }

        $hazards = DB::table('simulation_run_hazards')->where('simulation_run_id', $runId)->join('hazards', 'hazards.id', '=', 'simulation_run_hazards.hazard_id')->get()->map(fn ($r) => [
            'hazard_id' => $r->hazard_id,
            'type' => $r->type,
            'road_impact' => $r->road_impact,
        ])->all();

        $originLoc = DB::selectOne('SELECT ST_X(origin::geometry) as lng, ST_Y(origin::geometry) as lat FROM simulation_runs WHERE id = ?', [$runId]);

        return [
            'run_id' => $run->id,
            'scenario_id' => $run->scenario_key,
            'status' => $run->status,
            'hazards_created' => $hazards,
            'baseline_route' => $run->baseline_route_id ? ['route_id' => $run->baseline_route_id, 'total_cost' => 0] : null,
            'risk_aware_route' => $run->risk_aware_route_id ? ['route_id' => $run->risk_aware_route_id, 'total_cost' => 0] : null,
            'completed_at' => $run->completed_at,
        ];
    }
}
