<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class RouteGeometryTest extends TestCase
{
    use RefreshDatabase;

    private function createNetwork(): array
    {
        $a = (string) Str::uuid();
        $b = (string) Str::uuid();
        $c = (string) Str::uuid();
        $d = (string) Str::uuid();
        foreach ([$a => [106.80, -6.20], $b => [106.81, -6.20], $c => [106.80, -6.21], $d => [106.82, -6.20]] as $id => $coord) {
            DB::table('road_nodes')->insert([
                'id' => $id,
                'geom' => DB::raw("ST_GeogFromText('POINT({$coord[0]} {$coord[1]})')"),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        $ab = (string) Str::uuid();
        $bd = (string) Str::uuid();
        $ac = (string) Str::uuid();
        $cd = (string) Str::uuid();
        DB::table('road_segments')->insert([
            ['id' => $ab, 'from_node_id' => $a, 'to_node_id' => $b, 'geom' => DB::raw("ST_GeogFromText('LINESTRING(106.80 -6.20, 106.81 -6.20)')"), 'base_travel_cost' => 10, 'bidirectional' => true, 'created_at' => now(), 'updated_at' => now()],
            ['id' => $bd, 'from_node_id' => $b, 'to_node_id' => $d, 'geom' => DB::raw("ST_GeogFromText('LINESTRING(106.81 -6.20, 106.82 -6.20)')"), 'base_travel_cost' => 10, 'bidirectional' => true, 'created_at' => now(), 'updated_at' => now()],
            ['id' => $ac, 'from_node_id' => $a, 'to_node_id' => $c, 'geom' => DB::raw("ST_GeogFromText('LINESTRING(106.80 -6.20, 106.80 -6.21)')"), 'base_travel_cost' => 15, 'bidirectional' => true, 'created_at' => now(), 'updated_at' => now()],
            ['id' => $cd, 'from_node_id' => $c, 'to_node_id' => $d, 'geom' => DB::raw("ST_GeogFromText('LINESTRING(106.80 -6.21, 106.82 -6.20)')"), 'base_travel_cost' => 15, 'bidirectional' => true, 'created_at' => now(), 'updated_at' => now()],
        ]);

        return ['A' => $a, 'B' => $b, 'C' => $c, 'D' => $d, 'AB' => $ab, 'BD' => $bd, 'AC' => $ac, 'CD' => $cd];
    }

    private function dest(string $nodeId): string
    {
        $id = (string) Str::uuid();
        DB::table('destinations')->insert([
            'id' => $id, 'name' => 'Shelter', 'type' => 'Shelter',
            'geom' => DB::raw("ST_GeogFromText('POINT(106.82 -6.20)')"),
            'nearest_road_node_id' => $nodeId,
            'created_at' => now(), 'updated_at' => now(),
        ]);

        return $id;
    }

    public function test_post_returns_geometry_linestring(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        $res = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-1']);
        $res->assertStatus(201);
        $res->assertJsonStructure(['route_id', 'segments', 'geometry' => ['type', 'coordinates']]);
        $geom = $res->json('geometry');
        $this->assertSame('LineString', $geom['type']);
        $this->assertNotEmpty($geom['coordinates']);
        // [lng,lat] order - lng ~106.8, lat ~-6.2
        $first = $geom['coordinates'][0];
        $this->assertEqualsWithDelta(106.80, $first[0], 0.001);
        $this->assertEqualsWithDelta(-6.20, $first[1], 0.001);
        // coordinates count >= 2 and deduped joints: AB(2)+BD(2)-1 =3
        $this->assertGreaterThanOrEqual(3, count($geom['coordinates']));
    }

    public function test_get_by_id_returns_same_geometry(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        $res = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-2']);
        $id = $res->json('route_id');
        $geom1 = $res->json('geometry');
        $detail = $this->getJson("/api/v1/routes/{$id}");
        $detail->assertStatus(200);
        $this->assertSame($geom1['type'], $detail->json('geometry.type'));
        $this->assertSame($geom1['coordinates'], $detail->json('geometry.coordinates'));
    }

    public function test_active_returns_geometry(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-3']);
        $active = $this->getJson('/api/v1/routes/active', ['X-Session-Id' => 'geom-3']);
        $active->assertStatus(200);
        $this->assertSame('LineString', $active->json('geometry.type'));
        $this->assertNotEmpty($active->json('geometry.coordinates'));
    }

    public function test_geometry_follows_road_network_not_straight_line(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        // Block AB->BD path by hazard on BD
        DB::table('hazards')->insert([
            'id' => (string) Str::uuid(), 'type' => 'RoadBlockage', 'severity' => 'High', 'confidence' => 1.0,
            'road_impact' => 'Blocked', 'status' => 'Confirmed', 'source' => 'QuickTap',
            'location' => DB::raw("ST_GeogFromText('POINT(106.81 -6.20)')"),
            'road_segment_id' => $net['BD'], 'reported_at' => now(), 'updated_at' => now(),
        ]);
        $res = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-4']);
        $res->assertStatus(201);
        $coords = $res->json('geometry.coordinates');
        // Should go via AC+CD, which includes point 106.80,-6.21 (C node). Straight line would not.
        $hasC = false;
        foreach ($coords as $c) {
            if (abs($c[0] - 106.80) < 0.001 && abs($c[1] - -6.21) < 0.001) {
                $hasC = true;
            }
        }
        $this->assertTrue($hasC, 'Geometry should include C waypoint via AC->CD, not straight line');
        $this->assertNotContains($net['BD'], collect($res->json('segments'))->pluck('road_segment_id')->all());
    }

    public function test_cost_and_segments_unchanged(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        $res = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-5']);
        $this->assertEqualsWithDelta(20.0, $res->json('total_cost'), 0.01);
        $this->assertCount(2, $res->json('segments'));
        $this->assertEqualsWithDelta(10.0, $res->json('segments.0.base_travel_cost'), 0.001);
    }

    public function test_supersede_keeps_geometry(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        $r1 = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-6']);
        $id1 = $r1->json('route_id');
        $r2 = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]], ['X-Session-Id' => 'geom-6']);
        $r2->assertJsonPath('supersedes_route_id', $id1);
        $this->assertNotNull($r2->json('geometry'));
    }

    public function test_no_route_still_409_without_geometry(): void
    {
        $net = $this->createNetwork();
        $dest = $this->dest($net['D']);
        // Block all paths
        foreach ([$net['AB'], $net['BD'], $net['AC'], $net['CD']] as $seg) {
            DB::table('hazards')->insert([
                'id' => (string) Str::uuid(), 'type' => 'RoadBlockage', 'severity' => 'High', 'confidence' => 1.0,
                'road_impact' => 'Blocked', 'status' => 'Confirmed', 'source' => 'QuickTap',
                'location' => DB::raw("ST_GeogFromText('POINT(106.80 -6.20)')"),
                'road_segment_id' => $seg, 'reported_at' => now(), 'updated_at' => now(),
            ]);
        }
        $res = $this->postJson('/api/v1/routes', ['destination_id' => $dest, 'origin' => ['lat' => -6.20, 'lng' => 106.80]]);
        $res->assertStatus(409);
    }

    public function test_invalid_destination_404(): void
    {
        $res = $this->postJson('/api/v1/routes', ['destination_id' => (string) Str::uuid(), 'origin' => ['lat' => -6.20, 'lng' => 106.80]]);
        $res->assertStatus(404);
    }
}
