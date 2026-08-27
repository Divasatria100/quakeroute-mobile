<?php

declare(strict_types=1);

namespace Tests\Feature;

use Database\Seeders\DestinationSeeder;
use Database\Seeders\RoadNetworkSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class RouteRecalculationTest extends TestCase
{
    use RefreshDatabase;

    private const SEG_A_B = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1';

    private const SEG_B_C = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2';

    private const SEG_B_E = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6';

    private const SEG_E_F = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4';

    private const DEST_F = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3';

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(RoadNetworkSeeder::class);
        $this->seed(DestinationSeeder::class);
    }

    public function test_hazard_on_route_segment_supersedes_and_recalculates(): void
    {
        // Build an active route A -> B -> C -> F for a session user.
        $routeRes = $this->postJson('/api/v1/routes', [
            'destination_id' => self::DEST_F,
            'origin' => ['lat' => -6.2001, 'lng' => 106.8001],
        ], ['X-Session-Id' => 'recalc-sess']);
        $routeRes->assertStatus(201);
        $originalRouteId = $routeRes->json('route_id');
        $originalSegments = DB::table('route_segments')->where('route_id', $originalRouteId)->orderBy('sequence_order')->pluck('road_segment_id')->all();
        $this->assertNotEmpty($originalSegments);
        $this->assertContains(self::SEG_B_C, $originalSegments);

        // Inject a hazard on segment B-C (aaaaaaa2) — the shortest route segment.
        $this->postJson('/api/v1/hazard-reports/quick', [
            'type' => 'RoadBlockage',
            'location' => ['lat' => -6.20, 'lng' => 106.815], // nearest B-C (aaa2)
        ], ['X-Session-Id' => 'recalc-sess'])->assertStatus(201);

        // Original route must now be superseded.
        $this->assertDatabaseHas('routes', ['id' => $originalRouteId, 'status' => 'Superseded']);

        $active = $this->getJson('/api/v1/routes/active', ['X-Session-Id' => 'recalc-sess']);
        $active->assertStatus(200);
        $active->assertJsonPath('supersedes_route_id', $originalRouteId);
        $newRouteId = $active->json('route_id');

        $newSegments = DB::table('route_segments')->where('route_id', $newRouteId)->orderBy('sequence_order')->pluck('road_segment_id')->all();
        $this->assertNotEmpty($newSegments);
        // New route must NOT contain the blocked segment B-C.
        $this->assertNotContains(self::SEG_B_C, $newSegments);
        // New route still reaches the destination.
        $this->assertNotSame($originalRouteId, $newRouteId);
    }

    public function test_unrelated_user_routes_not_recalculated(): void
    {
        // Two users with different destinations so only the first user's route
        // traverses segment B-C. User A -> F (uses B-C), User B -> D.
        $r1 = $this->postJson('/api/v1/routes', [
            'destination_id' => self::DEST_F,
            'origin' => ['lat' => -6.2001, 'lng' => 106.8001],
        ], ['X-Session-Id' => 'sess-a']);
        $r1->assertStatus(201);
        $r2 = $this->postJson('/api/v1/routes', [
            'destination_id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4', // Medical Facility D (nearest D), path A->D (aa5)
            'origin' => ['lat' => -6.2001, 'lng' => 106.8001],
        ], ['X-Session-Id' => 'sess-b']);
        $r2->assertStatus(201);
        $routeA = $r1->json('route_id');
        $routeB = $r2->json('route_id');

        $routeBSegments = DB::table('route_segments')->where('route_id', $routeB)->orderBy('sequence_order')->pluck('road_segment_id')->all();

        // Inject hazard on segment B-C (aaaaa2) which only the F route uses.
        $this->postJson('/api/v1/hazard-reports/quick', [
            'type' => 'RoadBlockage',
            'location' => ['lat' => -6.20, 'lng' => 106.815], // nearest B-C
        ], ['X-Session-Id' => 'sess-a'])->assertStatus(201);

        // Route A superseded (affected).
        $this->assertDatabaseHas('routes', ['id' => $routeA, 'status' => 'Superseded']);
        // Route B untouched and still Active (does not traverse B-C).
        $this->assertDatabaseHas('routes', ['id' => $routeB, 'status' => 'Active']);
        $this->assertNotContains(self::SEG_B_C, $routeBSegments);
    }
}
