<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SimulationScenarioSeeder extends Seeder
{
    public function run(): void
    {
        $scenarios = [
            [
                'scenario_key' => 'no_hazard',
                'name' => 'No Hazard',
                'description' => 'Controlled network with no active hazards — baseline matches risk-aware.',
                'injected_observations' => json_encode([]),
            ],
            [
                'scenario_key' => 'blocked_road',
                'name' => 'Blocked Road',
                'description' => 'A segment on the shortest route is fully blocked — must find alternative.',
                'injected_observations' => json_encode([['type' => 'RoadBlockage', 'road_impact' => 'Blocked']]),
            ],
            [
                'scenario_key' => 'high_risk_hazard',
                'name' => 'High-Risk Hazard',
                'description' => 'Passable segment with high-severity high-confidence hazard — penalized but not blocked.',
                'injected_observations' => json_encode([['type' => 'Fire', 'severity' => 'High', 'road_impact' => 'PartiallyBlocked']]),
            ],
            [
                'scenario_key' => 'new_hazard_during_navigation',
                'name' => 'New Hazard During Navigation',
                'description' => 'New hazard appears on active route — triggers recalculation.',
                'injected_observations' => json_encode([['type' => 'DebrisRubble', 'road_impact' => 'Blocked']]),
            ],
            [
                'scenario_key' => 'conflicting_reports',
                'name' => 'Conflicting Reports',
                'description' => 'Two reports disagree on same segment — uncertain/conflicting status.',
                'injected_observations' => json_encode([['type' => 'Flood', 'road_impact' => 'Blocked'], ['type' => 'Flood', 'road_impact' => 'Passable']]),
            ],
            [
                'scenario_key' => 'ai_vision_hazard_report',
                'name' => 'AI Vision Hazard Report',
                'description' => 'Photo report via AI Vision — proposed hazard for confirmation.',
                'injected_observations' => json_encode([['type' => 'VisibleBuildingDamage', 'source' => 'AIVisionPhoto']]),
            ],
        ];

        foreach ($scenarios as $s) {
            DB::table('simulation_scenarios')->updateOrInsert(
                ['scenario_key' => $s['scenario_key']],
                $s
            );
        }
    }
}
