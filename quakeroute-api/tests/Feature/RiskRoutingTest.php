<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Modules\Risk\Services\HazardPenaltyCalculator;
use App\Modules\Risk\Services\RiskCalculationService;
use App\Modules\Risk\Services\SegmentCostCalculator;
use App\Modules\Risk\Services\UncertaintyPenaltyCalculator;
use App\Modules\Routing\Services\RiskAwareRoutingService;
use App\Modules\Routing\Support\GraphBuilder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class RiskRoutingTest extends TestCase
{
    use RefreshDatabase;

    private HazardPenaltyCalculator $hazardPenaltyCalculator;

    private UncertaintyPenaltyCalculator $uncertaintyPenaltyCalculator;

    private SegmentCostCalculator $segmentCostCalculator;

    private RiskCalculationService $riskService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->hazardPenaltyCalculator = new HazardPenaltyCalculator;
        $this->uncertaintyPenaltyCalculator = new UncertaintyPenaltyCalculator;
        $this->segmentCostCalculator = new SegmentCostCalculator($this->hazardPenaltyCalculator, $this->uncertaintyPenaltyCalculator);
        $this->riskService = new RiskCalculationService($this->hazardPenaltyCalculator, $this->uncertaintyPenaltyCalculator, $this->segmentCostCalculator);
    }

    // 1. No hazard → base cost
    public function test_no_hazard_returns_base_cost(): void
    {
        $cost = $this->segmentCostCalculator->calculate(20.0, []);
        self::assertSame(20.0, $cost);
    }

    // 2. Low severity 10 * 0.5 =5
    public function test_low_severity_penalty(): void
    {
        $penalty = $this->hazardPenaltyCalculator->calculate('Low', 0.5);
        self::assertEqualsWithDelta(5.0, $penalty, 0.001);
    }

    // 3. Medium 30*1.0=30
    public function test_medium_severity_penalty(): void
    {
        $penalty = $this->hazardPenaltyCalculator->calculate('Medium', 1.0);
        self::assertEqualsWithDelta(30.0, $penalty, 0.001);
    }

    // 4. High 100*0.9=90
    public function test_high_severity_penalty(): void
    {
        $penalty = $this->hazardPenaltyCalculator->calculate('High', 0.9);
        self::assertEqualsWithDelta(90.0, $penalty, 0.001);
    }

    // 5. Confirmed uncertainty 0
    public function test_confirmed_uncertainty_zero(): void
    {
        self::assertSame(0.0, $this->uncertaintyPenaltyCalculator->calculate('Confirmed'));
    }

    // 6. Reported 5
    public function test_reported_uncertainty_five(): void
    {
        self::assertSame(5.0, $this->uncertaintyPenaltyCalculator->calculate('Reported'));
    }

    // 7. UncertainConflicting 20
    public function test_conflicting_uncertainty_twenty(): void
    {
        self::assertSame(20.0, $this->uncertaintyPenaltyCalculator->calculate('UncertainConflicting'));
    }

    // 8. Multiple hazards MAX
    public function test_multiple_hazards_uses_max(): void
    {
        $hazards = [
            ['severity' => 'High', 'confidence' => 0.8, 'roadImpact' => 'Passable', 'status' => 'Confirmed'],
            ['severity' => 'Medium', 'confidence' => 0.9, 'roadImpact' => 'Passable', 'status' => 'Confirmed'],
        ];
        // High 80, Medium 27 → max 80, plus base 20 = 100
        $cost = $this->segmentCostCalculator->calculate(20.0, $hazards);
        self::assertEqualsWithDelta(100.0, $cost, 0.001);
    }

    // 9. Multiple uncertainties MAX
    public function test_multiple_uncertainties_uses_max(): void
    {
        $hazards = [
            ['severity' => 'Low', 'confidence' => 1.0, 'roadImpact' => 'Passable', 'status' => 'Reported'],
            ['severity' => 'Low', 'confidence' => 1.0, 'roadImpact' => 'Passable', 'status' => 'UncertainConflicting'],
        ];
        // hazard penalty max 10, uncertainty max 20, base 10 → 40
        $cost = $this->segmentCostCalculator->calculate(10.0, $hazards);
        self::assertEqualsWithDelta(40.0, $cost, 0.001);
    }

    // 10. Blocked excluded
    public function test_blocked_segment_is_inf(): void
    {
        $hazards = [
            ['severity' => 'High', 'confidence' => 1.0, 'roadImpact' => 'Blocked', 'status' => 'Confirmed'],
        ];
        $cost = $this->segmentCostCalculator->calculate(10.0, $hazards);
        self::assertSame((float) PHP_INT_MAX, $cost);
    }

    // 11. PartiallyBlocked remains routable
    public function test_partially_blocked_remains_routable(): void
    {
        $hazards = [
            ['severity' => 'Medium', 'confidence' => 1.0, 'roadImpact' => 'PartiallyBlocked', 'status' => 'Confirmed'],
        ];
        $cost = $this->segmentCostCalculator->calculate(10.0, $hazards);
        // 10 + 30 + 0 =40, not INF
        self::assertEqualsWithDelta(40.0, $cost, 0.001);
        self::assertNotSame((float) PHP_INT_MAX, $cost);
    }

    // 12. Safer alternative chosen (deterministic graph)
    public function test_safer_alternative_chosen(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B', 'C', 'D'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'BD', 'from_node_id' => 'B', 'to_node_id' => 'D', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => [
                    ['severity' => 'High', 'confidence' => 1.0, 'roadImpact' => 'Passable', 'status' => 'Confirmed'],
                ]],
                ['id' => 'AC', 'from_node_id' => 'A', 'to_node_id' => 'C', 'base_travel_cost' => 15, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'CD', 'from_node_id' => 'C', 'to_node_id' => 'D', 'base_travel_cost' => 15, 'bidirectional' => false, 'hazards' => []],
            ]
        );

        $service = new RiskAwareRoutingService($builder);
        $result = $service->findRouteOnGraph('A', 'D', $graph);

        self::assertTrue($result['success']);
        self::assertSame(['A', 'C', 'D'], $result['node_ids']);
        self::assertSame(['AC', 'CD'], $result['road_segment_ids']);
        self::assertEqualsWithDelta(30.0, $result['total_cost'], 0.001);
    }

    // 13. No alternative → NO_ROUTE
    public function test_no_alternative_returns_no_route(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => [
                    ['severity' => 'High', 'confidence' => 1.0, 'roadImpact' => 'Blocked', 'status' => 'Confirmed'],
                ]],
            ]
        );

        $service = new RiskAwareRoutingService($builder);
        $result = $service->findRouteOnGraph('A', 'B', $graph);

        self::assertFalse($result['success']);
        self::assertSame('NO_ROUTE', $result['reason']);
    }

    // 14. Bidirectional creates both directions
    public function test_bidirectional_creates_both_directions(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => true, 'hazards' => []],
            ]
        );

        self::assertCount(1, $graph['A']);
        self::assertCount(1, $graph['B']);
        self::assertSame('B', $graph['A'][0]['to']);
        self::assertSame('A', $graph['B'][0]['to']);
    }

    // 15. One-way creates only from→to
    public function test_one_way_creates_only_one_direction(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => []],
            ]
        );

        self::assertCount(1, $graph['A']);
        self::assertCount(0, $graph['B']);
    }

    // 16. Route total cost = sum
    public function test_route_total_cost_is_sum(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B', 'C'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'BC', 'from_node_id' => 'B', 'to_node_id' => 'C', 'base_travel_cost' => 20, 'bidirectional' => false, 'hazards' => []],
            ]
        );
        $service = new RiskAwareRoutingService($builder);
        $result = $service->findRouteOnGraph('A', 'C', $graph);
        self::assertEqualsWithDelta(30.0, $result['total_cost'], 0.001);
    }

    // 17. Dijkstra chooses minimum total cost
    public function test_dijkstra_chooses_minimum_cost(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B', 'C', 'D'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'BD', 'from_node_id' => 'B', 'to_node_id' => 'D', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'AC', 'from_node_id' => 'A', 'to_node_id' => 'C', 'base_travel_cost' => 100, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'CD', 'from_node_id' => 'C', 'to_node_id' => 'D', 'base_travel_cost' => 100, 'bidirectional' => false, 'hazards' => []],
            ]
        );
        $service = new RiskAwareRoutingService($builder);
        $result = $service->findRouteOnGraph('A', 'D', $graph);
        self::assertSame(['A', 'B', 'D'], $result['node_ids']);
    }

    // 18. Conflicting hazard does NOT auto block
    public function test_conflicting_does_not_auto_block(): void
    {
        $hazards = [
            ['severity' => 'High', 'confidence' => 1.0, 'roadImpact' => 'Passable', 'status' => 'UncertainConflicting'],
        ];
        $cost = $this->segmentCostCalculator->calculate(10.0, $hazards);
        // 10 + 100 + 20 =130, not INF
        self::assertEqualsWithDelta(130.0, $cost, 0.001);
        self::assertNotSame((float) PHP_INT_MAX, $cost);

        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 10, 'bidirectional' => false, 'hazards' => $hazards],
            ]
        );
        self::assertCount(1, $graph['A']); // still routable
    }

    // 19. High-risk direct vs safer longer (same as 12 but explicit)
    public function test_high_risk_direct_vs_safer_longer(): void
    {
        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->build(
            ['A', 'B', 'C', 'D'],
            [
                ['id' => 'AB', 'from_node_id' => 'A', 'to_node_id' => 'B', 'base_travel_cost' => 5, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'BD', 'from_node_id' => 'B', 'to_node_id' => 'D', 'base_travel_cost' => 5, 'bidirectional' => false, 'hazards' => [
                    ['severity' => 'High', 'confidence' => 1.0, 'roadImpact' => 'Passable', 'status' => 'Confirmed'],
                ]],
                ['id' => 'AC', 'from_node_id' => 'A', 'to_node_id' => 'C', 'base_travel_cost' => 20, 'bidirectional' => false, 'hazards' => []],
                ['id' => 'CD', 'from_node_id' => 'C', 'to_node_id' => 'D', 'base_travel_cost' => 20, 'bidirectional' => false, 'hazards' => []],
            ]
        );
        // Direct 5+5+100=110, alternative 40 → alternative wins
        $service = new RiskAwareRoutingService($builder);
        $result = $service->findRouteOnGraph('A', 'D', $graph);
        self::assertSame(['A', 'C', 'D'], $result['node_ids']);
    }

    // 20. DB persistence via GraphBuilder from database
    public function test_graph_builder_from_database(): void
    {
        // Create minimal road network in DB
        $a = (string) Str::uuid();
        $b = (string) Str::uuid();
        DB::table('road_nodes')->insert([
            ['id' => $a, 'geom' => DB::raw("ST_GeogFromText('POINT(106.80 -6.20)')"), 'created_at' => now(), 'updated_at' => now()],
            ['id' => $b, 'geom' => DB::raw("ST_GeogFromText('POINT(106.82 -6.20)')"), 'created_at' => now(), 'updated_at' => now()],
        ]);
        $segId = (string) Str::uuid();
        DB::table('road_segments')->insert([
            'id' => $segId,
            'from_node_id' => $a,
            'to_node_id' => $b,
            'geom' => DB::raw("ST_GeogFromText('LINESTRING(106.80 -6.20, 106.82 -6.20)')"),
            'base_travel_cost' => 10,
            'bidirectional' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $builder = new GraphBuilder($this->segmentCostCalculator);
        $graph = $builder->buildFromDatabase();

        self::assertArrayHasKey($a, $graph);
        self::assertArrayHasKey($b, $graph);
        self::assertCount(1, $graph[$a]);
        self::assertCount(1, $graph[$b]);
    }
}
