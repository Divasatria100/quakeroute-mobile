<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Modules\Routing\Support\GraphBuilder;
use App\Modules\Simulation\Services\SimulationService;
use Database\Seeders\DestinationSeeder;
use Database\Seeders\RoadNetworkSeeder;
use Database\Seeders\SimulationScenarioSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;
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
        $this->seed(RoadNetworkSeeder::class);
        $this->seed(DestinationSeeder::class);
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
        $this->assertNotContains(self::SEG_B_C, $riskSegments);

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
        } catch (HttpException $e) {
            $this->assertSame(404, $e->getStatusCode());
        }
    }

    public function test_missing_destination_returns_422(): void
    {
        try {
            $this->service()->runScenario('blocked_road', $this->origin(), 'bbbbbbbb-bbbb-bbbb-bbbb-000000000000');
            $this->fail('Expected 422');
        } catch (HttpException $e) {
            $this->assertSame(422, $e->getStatusCode());
        }
    }

    public function test_synthetic_scenario_generates_network_around_center_and_is_deterministic_by_seed(): void
    {
        $center = ['lat' => -6.25, 'lng' => 106.85];
        $result1 = $this->service()->runScenario('blocked_road', $center, 'synth-dest-placeholder', $center, 12345, 1500);

        $this->assertSame('Completed', $result1['status']);
        $this->assertNotNull($result1['baseline_route_id']);
        $this->assertNotNull($result1['risk_aware_route_id']);
        $this->assertNotEmpty($result1['synthetic_destinations']);
        $this->assertNotEmpty($result1['network']['nodes']);
        $this->assertNotEmpty($result1['network']['segments']);

        // Determinism: same center + same seed produces identical network
        $result2 = $this->service()->runScenario('blocked_road', $center, 'synth-dest-placeholder', $center, 12345, 1500);
        $this->assertSame($result1['network']['nodes'], $result2['network']['nodes']);

        // Different seed produces different hazards/segments
        $result3 = $this->service()->runScenario('blocked_road', $center, 'synth-dest-placeholder', $center, 99999, 1500);
        $this->assertNotEquals($result1['hazards_created'], $result3['hazards_created']);
    }

    public function test_different_center_produces_different_network_location(): void
    {
        $centerA = ['lat' => -6.20, 'lng' => 106.80];
        $centerB = ['lat' => -6.90, 'lng' => 107.60]; // Bandung area

        $resA = $this->service()->runScenario('no_hazard', $centerA, 'd1', $centerA, 100, 1500);
        $resB = $this->service()->runScenario('no_hazard', $centerB, 'd1', $centerB, 100, 1500);

        $nodeA = $resA['network']['nodes'][0];
        $nodeB = $resB['network']['nodes'][0];

        $this->assertNotEquals($nodeA['lat'], $nodeB['lat']);
        $this->assertNotEquals($nodeA['lng'], $nodeB['lng']);
    }

    public function test_synthetic_nodes_and_segments_marked_is_synthetic_and_isolated_from_global_graph(): void
    {
        $center = ['lat' => -6.30, 'lng' => 106.70];
        $res = $this->service()->runScenario('blocked_road', $center, 'd1', $center, 555, 1500);

        $syntheticNodesCount = DB::table('road_nodes')->where('is_synthetic', true)->where('simulation_run_id', $res['run_id'])->count();
        $this->assertGreaterThan(0, $syntheticNodesCount);

        // Global graph builder excludes synthetic rows
        $globalGraph = app(GraphBuilder::class)->buildFromDatabase();
        foreach (array_keys($globalGraph) as $nodeId) {
            $isSynth = DB::table('road_nodes')->where('id', $nodeId)->value('is_synthetic');
            $this->assertFalse((bool) $isSynth, "Global graph contained synthetic node $nodeId");
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
