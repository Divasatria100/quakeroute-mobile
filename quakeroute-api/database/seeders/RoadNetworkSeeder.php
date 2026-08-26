<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RoadNetworkSeeder extends Seeder
{
    public function run(): void
    {
        // Deterministic development network around Jakarta (-6.20, 106.80)
        // 6 nodes forming a 3x2 grid, 7 segments, fully connected
        $nodes = [
            ['id' => '11111111-1111-1111-1111-111111111111', 'label' => 'A', 'lng' => 106.80, 'lat' => -6.20],
            ['id' => '22222222-2222-2222-2222-222222222222', 'label' => 'B', 'lng' => 106.81, 'lat' => -6.20],
            ['id' => '33333333-3333-3333-3333-333333333333', 'label' => 'C', 'lng' => 106.82, 'lat' => -6.20],
            ['id' => '44444444-4444-4444-4444-444444444444', 'label' => 'D', 'lng' => 106.80, 'lat' => -6.21],
            ['id' => '55555555-5555-5555-5555-555555555555', 'label' => 'E', 'lng' => 106.81, 'lat' => -6.21],
            ['id' => '66666666-6666-6666-6666-666666666666', 'label' => 'F', 'lng' => 106.82, 'lat' => -6.21],
        ];

        foreach ($nodes as $n) {
            DB::table('road_nodes')->updateOrInsert(
                ['id' => $n['id']],
                [
                    'label' => $n['label'],
                    'geom' => DB::raw("ST_GeogFromText('POINT({$n['lng']} {$n['lat']})')"),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }

        $segments = [
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'from' => '11111111-1111-1111-1111-111111111111', 'to' => '22222222-2222-2222-2222-222222222222', 'wkt' => 'LINESTRING(106.80 -6.20, 106.81 -6.20)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'from' => '22222222-2222-2222-2222-222222222222', 'to' => '33333333-3333-3333-3333-333333333333', 'wkt' => 'LINESTRING(106.81 -6.20, 106.82 -6.20)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3', 'from' => '44444444-4444-4444-4444-444444444444', 'to' => '55555555-5555-5555-5555-555555555555', 'wkt' => 'LINESTRING(106.80 -6.21, 106.81 -6.21)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4', 'from' => '55555555-5555-5555-5555-555555555555', 'to' => '66666666-6666-6666-6666-666666666666', 'wkt' => 'LINESTRING(106.81 -6.21, 106.82 -6.21)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5', 'from' => '11111111-1111-1111-1111-111111111111', 'to' => '44444444-4444-4444-4444-444444444444', 'wkt' => 'LINESTRING(106.80 -6.20, 106.80 -6.21)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6', 'from' => '22222222-2222-2222-2222-222222222222', 'to' => '55555555-5555-5555-5555-555555555555', 'wkt' => 'LINESTRING(106.81 -6.20, 106.81 -6.21)'],
            ['id' => 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa7', 'from' => '33333333-3333-3333-3333-333333333333', 'to' => '66666666-6666-6666-6666-666666666666', 'wkt' => 'LINESTRING(106.82 -6.20, 106.82 -6.21)'],
        ];

        foreach ($segments as $s) {
            DB::table('road_segments')->updateOrInsert(
                ['id' => $s['id']],
                [
                    'from_node_id' => $s['from'],
                    'to_node_id' => $s['to'],
                    'geom' => DB::raw("ST_GeogFromText('{$s['wkt']}')"),
                    'base_travel_cost' => 10,
                    'bidirectional' => true,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }
    }
}
