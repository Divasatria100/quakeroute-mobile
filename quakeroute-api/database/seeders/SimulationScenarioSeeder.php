<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SimulationScenarioSeeder extends Seeder
{
    public function run(): void
    {
        // Deterministic segment identifiers from RoadNetworkSeeder:
        // A->B 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'
        // B->C 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'  (the B-C segment we target)
        // D->E 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3'
        // E->F 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4'
        $segBtoC = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2';

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
                'description' => 'Segment B-C on the shortest route is fully blocked — Dijkstra must find an alternative avoiding it.',
                'injected_observations' => json_encode([
                    ['type' => 'RoadBlockage', 'severity' => 'High', 'road_impact' => 'Blocked', 'road_segment_id' => $segBtoC, 'status' => 'Confirmed'],
                ]),
            ],
            [
                'scenario_key' => 'high_risk_hazard',
                'name' => 'High-Risk Hazard',
                'description' => 'Shortest segment B-C carries a high-severity, high-confidence hazard — penalized heavily, so a safer alternative is chosen.',
                'injected_observations' => json_encode([
                    ['type' => 'Fire', 'severity' => 'High', 'confidence' => 1.0, 'road_impact' => 'PartiallyBlocked', 'road_segment_id' => $segBtoC, 'status' => 'Confirmed'],
                ]),
            ],
            [
                'scenario_key' => 'new_hazard_during_navigation',
                'name' => 'New Hazard During Navigation',
                'description' => 'New debris blocks a previously-safe route segment — recalculation produces a replacement active route.',
                'injected_observations' => json_encode([
                    ['type' => 'DebrisRubble', 'severity' => 'High', 'road_impact' => 'Blocked', 'road_segment_id' => $segBtoC, 'status' => 'Confirmed'],
                ]),
            ],
            [
                'scenario_key' => 'conflicting_reports',
                'name' => 'Conflicting Reports',
                'description' => 'Two reports disagree on B-C — the stronger report blocks it, forcing a detour.',
                'injected_observations' => json_encode([
                    ['type' => 'Flood', 'severity' => 'High', 'road_impact' => 'Blocked', 'status' => 'Confirmed', 'road_segment_id' => $segBtoC],
                    ['type' => 'Flood', 'severity' => 'Low', 'road_impact' => 'Passable', 'status' => 'UncertainConflicting', 'road_segment_id' => $segBtoC],
                ]),
            ],
            [
                'scenario_key' => 'ai_vision_hazard_report',
                'name' => 'AI Vision Hazard Report',
                'description' => 'Photo report via AI Vision — proposed hazard on B-C for confirmation.',
                'injected_observations' => json_encode([
                    ['type' => 'VisibleBuildingDamage', 'severity' => 'Medium', 'road_impact' => 'PartiallyBlocked', 'source' => 'AIVisionPhoto', 'road_segment_id' => $segBtoC, 'status' => 'Confirmed'],
                ]),
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
