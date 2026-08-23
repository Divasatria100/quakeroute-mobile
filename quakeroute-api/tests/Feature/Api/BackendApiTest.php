<?php

declare(strict_types=1);

namespace Tests\Feature\Api;

use App\Modules\AI\Contracts\AIProviderInterface;
use App\Modules\AI\Providers\FakeAIProvider;
use App\Modules\AI\Support\AIProviderException;
use Database\Seeders\SimulationScenarioSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class BackendApiTest extends TestCase
{
    use RefreshDatabase;

    protected $seed = true;

    private function createRoadNetwork(): array
    {
        $a = (string) Str::uuid();
        $b = (string) Str::uuid();
        $c = (string) Str::uuid();
        $d = (string) Str::uuid();

        foreach ([$a, $b, $c, $d] as $id) {
            DB::table('road_nodes')->insert([
                'id' => $id,
                'geom' => DB::raw("ST_GeogFromText('POINT(106.80 -6.20)')"),
                'label' => null,
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

    private function createDestination(?string $nearestNodeId = null): string
    {
        $id = (string) Str::uuid();
        DB::table('destinations')->insert([
            'id' => $id,
            'name' => 'Shelter Test',
            'type' => 'Shelter',
            'geom' => DB::raw("ST_GeogFromText('POINT(106.82 -6.20)')"),
            'nearest_road_node_id' => $nearestNodeId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $id;
    }

    private function setFakeResult(array $result): void
    {
        /** @var FakeAIProvider $provider */
        $provider = app(AIProviderInterface::class);
        if ($provider instanceof FakeAIProvider) {
            $provider->setNextResult($result);
        }
    }

    private function setFakeException(\Throwable $e): void
    {
        /** @var FakeAIProvider $provider */
        $provider = app(AIProviderInterface::class);
        if ($provider instanceof FakeAIProvider) {
            $provider->setNextException($e);
        }
    }

    public function test_photo_report_success(): void
    {
        $this->setFakeResult([
            'type' => 'RoadBlockage',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.72,
            'latitude' => null,
            'longitude' => null,
            'evidence' => 'photo',
        ]);

        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $response = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
            'note' => 'test note',
        ], ['X-Session-Id' => 'sess-1']);

        $response->assertStatus(201);
        $response->assertJsonStructure(['suggestion_id', 'status', 'proposed_hazard' => ['type', 'severity', 'confidence', 'road_impact']]);
        $this->assertDatabaseHas('hazard_reports', ['mode' => 'Photo']);
        $this->assertDatabaseHas('hazard_suggestions', ['proposed_type' => 'RoadBlockage']);
        $this->assertDatabaseCount('hazards', 0);
    }

    public function test_photo_report_validation_failure(): void
    {
        $response = $this->post('/api/v1/hazard-reports/photo', [
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ], ['X-Session-Id' => 'sess-1']);
        $response->assertStatus(422);
        $response->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_photo_ai_failure_returns_503(): void
    {
        $this->setFakeException(AIProviderException::unavailable('AI down'));
        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $response = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $response->assertStatus(503);
        $response->assertJsonPath('error.code', 'AI_PROVIDER_UNAVAILABLE');
    }

    public function test_text_report_success(): void
    {
        $this->setFakeResult([
            'type' => 'DebrisRubble',
            'severity' => 'High',
            'roadImpact' => 'PartiallyBlocked',
            'confidence' => 0.65,
            'latitude' => null,
            'longitude' => null,
        ]);

        $response = $this->postJson('/api/v1/hazard-reports/text', [
            'text' => 'Jalan di depan pasar tertutup reruntuhan',
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ], ['X-Session-Id' => 'sess-text']);

        $response->assertStatus(201);
        $response->assertJsonStructure(['hazards' => [['hazard_id', 'type', 'severity']]]);
        $this->assertDatabaseHas('hazards', ['type' => 'DebrisRubble']);
    }

    public function test_text_invalid_payload(): void
    {
        $response = $this->postJson('/api/v1/hazard-reports/text', [
            'text' => '',
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $response->assertStatus(422);
    }

    public function test_quick_report_success(): void
    {
        $response = $this->postJson('/api/v1/hazard-reports/quick', [
            'type' => 'Fire',
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ], ['X-Session-Id' => 'sess-quick']);

        $response->assertStatus(201);
        $response->assertJsonPath('type', 'Fire');
        $this->assertDatabaseHas('hazards', ['type' => 'Fire', 'source' => 'QuickTap']);
    }

    public function test_quick_invalid_type(): void
    {
        $response = $this->postJson('/api/v1/hazard-reports/quick', [
            'type' => 'InvalidType',
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $response->assertStatus(422);
    }

    public function test_confirm_suggestion_success(): void
    {
        $this->setFakeResult([
            'type' => 'RoadBlockage',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.8,
            'latitude' => null,
            'longitude' => null,
        ]);
        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $photoRes = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $suggestionId = $photoRes->json('suggestion_id');

        $response = $this->postJson("/api/v1/hazard-suggestions/{$suggestionId}/confirm", []);
        $response->assertStatus(200);
        $response->assertJsonPath('type', 'RoadBlockage');
        $this->assertDatabaseHas('hazards', ['id' => $response->json('hazard_id')]);
    }

    public function test_confirm_with_edits(): void
    {
        $this->setFakeResult([
            'type' => 'Fire',
            'severity' => 'Low',
            'roadImpact' => 'Passable',
            'confidence' => 0.7,
            'latitude' => null,
            'longitude' => null,
        ]);
        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $photoRes = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $suggestionId = $photoRes->json('suggestion_id');

        $response = $this->postJson("/api/v1/hazard-suggestions/{$suggestionId}/confirm", [
            'edits' => ['type' => 'Flood', 'severity' => 'High', 'road_impact' => 'Blocked'],
        ]);
        $response->assertStatus(200);
        $response->assertJsonPath('type', 'Flood');
        $response->assertJsonPath('severity', 'High');
    }

    public function test_confirm_not_found(): void
    {
        $response = $this->postJson('/api/v1/hazard-suggestions/'.Str::uuid().'/confirm', []);
        $response->assertStatus(404);
    }

    public function test_confirm_already_confirmed_conflict(): void
    {
        $this->setFakeResult([
            'type' => 'Fire',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.8,
            'latitude' => null,
            'longitude' => null,
        ]);
        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $photoRes = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $sid = $photoRes->json('suggestion_id');
        $this->postJson("/api/v1/hazard-suggestions/{$sid}/confirm", []);
        $second = $this->postJson("/api/v1/hazard-suggestions/{$sid}/confirm", []);
        $second->assertStatus(409);
    }

    public function test_reject_success(): void
    {
        $this->setFakeResult([
            'type' => 'Flood',
            'severity' => 'Medium',
            'roadImpact' => 'PartiallyBlocked',
            'confidence' => 0.6,
            'latitude' => null,
            'longitude' => null,
        ]);
        $file = UploadedFile::fake()->create('hazard.jpg', 100, 'image/jpeg');
        $photoRes = $this->post('/api/v1/hazard-reports/photo', [
            'photo' => $file,
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $sid = $photoRes->json('suggestion_id');
        $response = $this->postJson("/api/v1/hazard-suggestions/{$sid}/reject", []);
        $response->assertStatus(200);
        $response->assertJsonPath('status', 'Rejected');
        $this->assertDatabaseCount('hazards', 0);
    }

    public function test_hazards_list_and_detail(): void
    {
        $this->createDestination();
        $this->postJson('/api/v1/hazard-reports/quick', [
            'type' => 'Fire',
            'location' => ['lat' => -6.20, 'lng' => 106.81],
        ]);
        $list = $this->getJson('/api/v1/hazards');
        $list->assertStatus(200);
        $list->assertJsonStructure(['hazards']);
        $hazardId = $list->json('hazards.0.hazard_id');
        $detail = $this->getJson("/api/v1/hazards/{$hazardId}");
        $detail->assertStatus(200);
        $detail->assertJsonPath('hazard_id', $hazardId);
        $detail->assertJsonStructure(['conflicting_with']);

        $notFound = $this->getJson('/api/v1/hazards/'.Str::uuid());
        $notFound->assertStatus(404);
    }

    public function test_destinations_list(): void
    {
        $net = $this->createRoadNetwork();
        $this->createDestination($net['A']);
        $response = $this->getJson('/api/v1/destinations');
        $response->assertStatus(200);
        $response->assertJsonStructure(['destinations' => [['destination_id', 'name', 'type', 'location']]]);
    }

    public function test_route_success_and_active_and_detail(): void
    {
        $net = $this->createRoadNetwork();
        $destId = $this->createDestination($net['D']);

        $response = $this->postJson('/api/v1/routes', [
            'destination_id' => $destId,
            'origin' => ['lat' => -6.20, 'lng' => 106.80],
        ], ['X-Session-Id' => 'route-sess-1']);
        $response->assertStatus(201);
        $routeId = $response->json('route_id');

        $detail = $this->getJson("/api/v1/routes/{$routeId}");
        $detail->assertStatus(200);

        $active = $this->getJson('/api/v1/routes/active', ['X-Session-Id' => 'route-sess-1']);
        $active->assertStatus(200);
        $active->assertJsonPath('route_id', $routeId);

        $second = $this->postJson('/api/v1/routes', [
            'destination_id' => $destId,
            'origin' => ['lat' => -6.20, 'lng' => 106.81],
        ], ['X-Session-Id' => 'route-sess-1']);
        $second->assertStatus(201);
        $second->assertJsonPath('supersedes_route_id', $routeId);

        $old = $this->getJson("/api/v1/routes/{$routeId}");
        $old->assertJsonPath('status', 'Superseded');
    }

    public function test_route_destination_not_found(): void
    {
        $response = $this->postJson('/api/v1/routes', [
            'destination_id' => (string) Str::uuid(),
            'origin' => ['lat' => -6.20, 'lng' => 106.80],
        ]);
        $response->assertStatus(404);
    }

    public function test_simulation_scenarios_and_run(): void
    {
        $this->seed(SimulationScenarioSeeder::class);
        $net = $this->createRoadNetwork();
        $destId = $this->createDestination($net['D']);

        $list = $this->getJson('/api/v1/simulation/scenarios');
        $list->assertStatus(200);
        $list->assertJsonCount(6, 'scenarios');

        $run = $this->postJson('/api/v1/simulation/scenarios/blocked_road/run', [
            'origin' => ['lat' => -6.20, 'lng' => 106.80],
            'destination_id' => $destId,
        ]);
        $run->assertStatus(202);
        $runId = $run->json('run_id');

        $get = $this->getJson("/api/v1/simulation/runs/{$runId}");
        $get->assertStatus(200);
        $get->assertJsonPath('scenario_id', 'blocked_road');

        $invalid = $this->postJson('/api/v1/simulation/scenarios/invalid/run', [
            'origin' => ['lat' => -6.20, 'lng' => 106.80],
            'destination_id' => $destId,
        ]);
        $invalid->assertStatus(404);

        $notFound = $this->getJson('/api/v1/simulation/runs/'.Str::uuid());
        $notFound->assertStatus(404);
    }

    public function test_voice_not_implemented(): void
    {
        $response = $this->post('/api/v1/hazard-reports/voice', [], ['X-Session-Id' => 'sess']);
        $response->assertStatus(501);
    }
}
