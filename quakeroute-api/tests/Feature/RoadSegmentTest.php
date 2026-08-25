<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class RoadSegmentTest extends TestCase
{
    use RefreshDatabase;

    private function createSegment(string $id, string $wkt, float $cost = 10): void
    {
        $a = (string) Str::uuid();
        $b = (string) Str::uuid();
        DB::table('road_nodes')->insert([
            ['id' => $a, 'geom' => DB::raw("ST_GeogFromText('POINT(106.8 -6.2)')"), 'created_at' => now(), 'updated_at' => now()],
            ['id' => $b, 'geom' => DB::raw("ST_GeogFromText('POINT(106.82 -6.2)')"), 'created_at' => now(), 'updated_at' => now()],
        ]);
        // we reuse a/b but need distinct for each segment to avoid fk clash, simpler create new nodes per segment call
        // Actually caller should have created nodes; this helper expects nodes exist; override to use provided a/b
        DB::table('road_segments')->insert([
            'id' => $id,
            'from_node_id' => $a,
            'to_node_id' => $b,
            'geom' => DB::raw("ST_GeogFromText('$wkt')"),
            'base_travel_cost' => $cost,
            'bidirectional' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_list_returns_geojson(): void
    {
        $id = (string) Str::uuid();
        $this->createSegment($id, 'LINESTRING(106.8 -6.2, 106.81 -6.2)');
        $res = $this->getJson('/api/v1/road-segments');
        $res->assertStatus(200);
        $res->assertJsonStructure(['data' => [['id', 'geometry' => ['type', 'coordinates'], 'condition', 'base_travel_cost']]]);
        $data = $res->json('data');
        $this->assertCount(1, $data);
        $this->assertSame('LineString', $data[0]['geometry']['type']);
        $this->assertSame(106.8, $data[0]['geometry']['coordinates'][0][0]);
        $this->assertSame(-6.2, $data[0]['geometry']['coordinates'][0][1]);
        $this->assertSame('Safe', $data[0]['condition']);
    }

    public function test_condition_reflects_hazard(): void
    {
        $id = (string) Str::uuid();
        $this->createSegment($id, 'LINESTRING(106.8 -6.2, 106.81 -6.2)');
        DB::table('hazards')->insert([
            'id' => (string) Str::uuid(),
            'type' => 'Fire',
            'severity' => 'High',
            'confidence' => 0.9,
            'road_impact' => 'Blocked',
            'status' => 'Confirmed',
            'source' => 'QuickTap',
            'location' => DB::raw("ST_GeogFromText('POINT(106.8 -6.2)')"),
            'road_segment_id' => $id,
            'reported_at' => now(),
            'updated_at' => now(),
        ]);
        $res = $this->getJson('/api/v1/road-segments');
        $res->assertStatus(200);
        $this->assertSame('Critical', $res->json('data.0.condition'));
    }

    public function test_condition_uncertain(): void
    {
        $id = (string) Str::uuid();
        $this->createSegment($id, 'LINESTRING(106.8 -6.2, 106.81 -6.2)');
        DB::table('hazards')->insert([
            'id' => (string) Str::uuid(),
            'type' => 'Fire',
            'severity' => 'Low',
            'confidence' => 0.5,
            'road_impact' => 'Passable',
            'status' => 'UncertainConflicting',
            'source' => 'QuickTap',
            'location' => DB::raw("ST_GeogFromText('POINT(106.8 -6.2)')"),
            'road_segment_id' => $id,
            'reported_at' => now(),
            'updated_at' => now(),
        ]);
        $res = $this->getJson('/api/v1/road-segments');
        $this->assertSame('Uncertain', $res->json('data.0.condition'));
    }

    public function test_empty_returns_empty_array(): void
    {
        $res = $this->getJson('/api/v1/road-segments');
        $res->assertStatus(200);
        $res->assertJson(['data' => []]);
    }

    public function test_invalid_bbox_returns_400(): void
    {
        $res = $this->getJson('/api/v1/road-segments?bbox=invalid');
        $res->assertStatus(400);
    }
}
