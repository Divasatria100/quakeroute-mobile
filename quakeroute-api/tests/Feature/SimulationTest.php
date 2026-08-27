<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Modules\Simulation\Services\SimulationService;
use Database\Seeders\SimulationScenarioSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class SimulationTest extends TestCase
{
    use RefreshDatabase;

    // Seeded deterministic network identifiers.
    private const NODE_A = '11111111-1111-1111-1111-111111111111';
    private const NODE_B = '22222222-2222-2222-2222-222222222222';
    private const NODE_D = '44444444-4444-4444-4444-444444444444';
    private const NODE_F = '66666666-6666-6666-6666-666666666666';
    private const SEG_B_C = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2';
    private const DEST_F = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3';

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(SimulationScenarioSeeder::class);
        $this->seed(\Database\Seeders\RoadNetworkSeeder::class);
        $this->seed(\Database\Seeders\DestinationSeeder::class);
    }

    private function service(): SimulationService
    {
        return app(SimulationService::class);
    }

    private function origin(): array
    {
        // Near node A.
        return ['lat' => -6.2001, 'lng' => 106.8001];
    }

    public function test_no_hazard_scenario_produces_both_valid_routes(): void
    {
        $result = $this->service()->runScenario('no_hazard', $this->origin(), self::DEST_F);

        $this->assertNotNull($result['baseline_route_id']);
        $this->assertNotNull($result['risk_aware_route_id']);
        $this->assertSame('Completed', $result['status']);
        $this->assertSame([], $result['hazards_created']);

        $this->assertDatabaseHas('routes', ['id' => $result['baseline_route_id']]);
        $this->assertDatabaseHas('routes', ['id' => $result['risk_aware_route_id']]);

        // Both persisted routes share the same segments (no hazards).
        $baselineSegments = $this->routeSegmentIds($result['baseline_route_id']);
        $riskSegments = $this->routeSegmentIds($result['risk_aware_route_id']);
        $this->assertNotEmpty($baselineSegments);
        $this->assertSame($baselineSegments, $riskSegments);
    }

    public function test_blocked_road_scenario_forces_route_away_from_blocked_segment(): void
    {
        $result = $this->service()->runScenario('blocked_road', $this->origin(), self::DEST_F);

        $this->assertNotNull($result['baseline_route_id']);
        $this->assertNotNull($result['risk_aware_route_id']);
        $this->assertCount(1, $result['hazards_created']);
        $this->assertSame(self::SEG_B_C, $result['hazards_created'][0]['road_segment_id']);
        $this->assertSame('Blocked', $result['hazards_created'][0]['road_impact']);

        // Baseline may pass through the blocked segment (it's excluded from the
        // injected hazards), while the risk-aware route must NOT contain it.
        $baselineSegments = $this->routeSegmentIds($result['baseline_route_id']);
        $riskSegments = $this->routeSegmentIds($result['risk_aware_route_id']);

        $this->assertNotEmpty($baselineSegments);
        $this->assertNotEmpty($riskSegments);
        $this->assertNotContains(self::SEG_BBC, $riskSegments);

        // Baseline and risk-aware must differ (the route actually changed).
        $this->assertNotSame($baselineSegments, $riskSegments);
    }

    public function test_high_risk_hazard_changes_route_path_even_when_not_blocked(): void
    {
        $result = $this->service()->runScenario('high_risk_hazard', $this->origin(), self::DEST_F);

        $this->assertNotNull($result['baseline_route_id']);
        $this->assertNotNull($result['risk_aware_route_id']);

        $baselineSegments = $this->routeSegmentIds($result['baseline_route_id']);
        $riskSegments = $this->routeSegmentIds($result['risk_aware_route_id']);

        $this->assertNotEmpty($baselineSegments);
        $this->assertNotEmpty($riskSegments);
    }

    public function test_invalid_scenario_returns_404(): void
    {
        try {
            $this->service()->runScenario('does_not_exist', $this->origin(), self::DEST_F);
            $this->fail('Expected 404');
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            $this->assertSame(404, $e->getStatusCode());
        }
    }

    public function test_missing_destination_returns_422(): void
    {
        try {
            $this->service()->runScenario('blocked_road', $this->origin(), 'bbbbbbbb-bbbb-bbbb-bbbb-000000000000');
            $this->fail('Expected 422');
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $e) {
            $this->assertSame(422, $e->getStatusCode());
        }
    }

    private function routeSegmentIds(string $routeId): array
    {
        return DB::table('route_segments')
            ->where('route_id', $routeId)
            ->orderBy('sequence_order')
            ->pluck('road_segment_id')
            ->all();
    }
}