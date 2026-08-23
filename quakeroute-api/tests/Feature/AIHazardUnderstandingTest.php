<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Modules\AI\DTOs\StructuredHazardDTO;
use App\Modules\AI\Providers\FakeAIProvider;
use App\Modules\AI\Services\HazardUnderstandingService;
use App\Modules\AI\Support\AIProviderException;
use App\Modules\AI\Support\HazardSuggestionValidator;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

final class AIHazardUnderstandingTest extends TestCase
{
    use RefreshDatabase;

    private function createHazardReport(string $rawText, string $mode = 'Text'): string
    {
        $id = (string) Str::uuid();
        DB::table('hazard_reports')->insert([
            'id' => $id,
            'user_id' => null,
            'mode' => $mode,
            'raw_text' => $rawText,
            'photo_url' => null,
            'audio_url' => null,
            'note' => null,
            'location' => DB::raw("ST_GeogFromText('POINT(106.81 -6.20)')"),
            'created_at' => now(),
        ]);

        return $id;
    }

    private function makeService(?array $nextResult = null, ?\Throwable $nextException = null): HazardUnderstandingService
    {
        $provider = new FakeAIProvider($nextResult, $nextException);
        $validator = new HazardSuggestionValidator;

        return new HazardUnderstandingService($provider, $validator);
    }

    public function test_valid_road_blockage_is_persisted(): void
    {
        $reportId = $this->createHazardReport('Jalan utama tertutup pohon besar sehingga mobil tidak dapat lewat.');

        $service = $this->makeService([
            'type' => 'RoadBlockage',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.92,
            'latitude' => null,
            'longitude' => null,
            'evidence' => 'Jalan utama tertutup pohon besar',
        ]);

        $result = $service->processReport($reportId);

        self::assertTrue($result['success']);
        self::assertNotNull($result['suggestionId']);
        self::assertInstanceOf(StructuredHazardDTO::class, $result['dto']);
        self::assertSame('RoadBlockage', $result['dto']->type);
        self::assertSame('Blocked', $result['dto']->roadImpact);

        $row = DB::table('hazard_suggestions')->where('id', $result['suggestionId'])->first();
        self::assertNotNull($row);
        self::assertSame($reportId, $row->hazard_report_id);
        self::assertSame('PendingConfirmation', $row->status);
        self::assertSame('RoadBlockage', $row->proposed_type);
        self::assertEqualsWithDelta(0.92, (float) $row->proposed_confidence, 0.001);

        // Must not create hazards automatically
        self::assertSame(0, DB::table('hazards')->count());
    }

    public function test_minor_hazard_passable(): void
    {
        $reportId = $this->createHazardReport('Beberapa bagian jalan tergenang air dangkal tetapi motor masih bisa lewat.');

        $service = $this->makeService([
            'type' => 'Flood',
            'severity' => 'Low',
            'roadImpact' => 'Passable',
            'confidence' => 0.78,
            'latitude' => null,
            'longitude' => null,
            'evidence' => 'tergenang air dangkal',
        ]);

        $result = $service->processReport($reportId);

        self::assertTrue($result['success']);
        self::assertSame('Flood', $result['dto']->type);
        self::assertSame('Low', $result['dto']->severity);
        self::assertSame('Passable', $result['dto']->roadImpact);
    }

    public function test_invalid_ai_json_is_rejected(): void
    {
        $reportId = $this->createHazardReport('Jalan tertutup');

        $provider = new FakeAIProvider;
        $provider->setNextRaw('this is not json');
        $service = new HazardUnderstandingService($provider, new HazardSuggestionValidator);

        $result = $service->processReport($reportId);

        self::assertFalse($result['success']);
        self::assertNull($result['suggestionId']);
        self::assertSame(0, DB::table('hazard_suggestions')->count());
        self::assertSame(0, DB::table('hazards')->count());
    }

    public function test_invalid_confidence_is_rejected(): void
    {
        $reportId = $this->createHazardReport('Jalan tertutup');

        $service = $this->makeService([
            'type' => 'RoadBlockage',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 1.5,
            'latitude' => null,
            'longitude' => null,
        ]);

        $result = $service->processReport($reportId);

        self::assertFalse($result['success']);
        self::assertSame(0, DB::table('hazard_suggestions')->count());
    }

    public function test_unsupported_hazard_type_is_rejected(): void
    {
        $reportId = $this->createHazardReport('Alien invasion on road');

        $service = $this->makeService([
            'type' => 'AlienInvasion',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.9,
            'latitude' => null,
            'longitude' => null,
        ]);

        $result = $service->processReport($reportId);

        self::assertFalse($result['success']);
        self::assertSame(0, DB::table('hazard_suggestions')->count());
    }

    public function test_missing_location_is_allowed_without_fabrication(): void
    {
        $reportId = $this->createHazardReport('Jalan retak sedikit');

        $service = $this->makeService([
            'type' => 'DebrisRubble',
            'severity' => 'Medium',
            'roadImpact' => 'PartiallyBlocked',
            'confidence' => 0.75,
            'latitude' => null,
            'longitude' => null,
        ]);

        $result = $service->processReport($reportId);

        self::assertTrue($result['success']);
        self::assertNull($result['dto']->latitude);
        self::assertNull($result['dto']->longitude);

        // Ensure original report location still exists as geography and not overwritten
        $loc = DB::selectOne('SELECT ST_AsText(location::geometry) as wkt FROM hazard_reports WHERE id = ?', [$reportId]);
        self::assertNotNull($loc);
        self::assertStringContainsString('POINT', $loc->wkt);
    }

    public function test_invalid_coordinates_are_rejected(): void
    {
        $reportId = $this->createHazardReport('Jalan banjir');

        $service = $this->makeService([
            'type' => 'Flood',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.8,
            'latitude' => 100.0,
            'longitude' => 200.0,
        ]);

        $result = $service->processReport($reportId);

        self::assertFalse($result['success']);
        self::assertSame(0, DB::table('hazard_suggestions')->count());
    }

    public function test_ai_provider_timeout_is_handled_gracefully(): void
    {
        $reportId = $this->createHazardReport('Jalan tertutup');

        $provider = new FakeAIProvider;
        $provider->setNextException(AIProviderException::timeout('timeout simulated'));
        $service = new HazardUnderstandingService($provider, new HazardSuggestionValidator);

        $result = $service->processReport($reportId);

        self::assertFalse($result['success']);
        self::assertNull($result['suggestionId']);
        self::assertSame(0, DB::table('hazard_suggestions')->count());
        self::assertSame(0, DB::table('hazards')->count());
    }

    public function test_persistence_links_correct_report_and_no_auto_confirmation(): void
    {
        $reportId = $this->createHazardReport('Jalan utama tertutup pohon besar');

        $service = $this->makeService([
            'type' => 'RoadBlockage',
            'severity' => 'High',
            'roadImpact' => 'Blocked',
            'confidence' => 0.88,
            'latitude' => -6.21,
            'longitude' => 106.82,
            'evidence' => 'pohon besar',
        ]);

        $result = $service->processReport($reportId);

        self::assertTrue($result['success']);
        self::assertEqualsWithDelta(-6.21, $result['dto']->latitude, 0.001);
        self::assertEqualsWithDelta(106.82, $result['dto']->longitude, 0.001);

        $suggestion = DB::table('hazard_suggestions')->where('id', $result['suggestionId'])->first();
        self::assertSame($reportId, $suggestion->hazard_report_id);
        self::assertSame(0, DB::table('hazards')->count());

        // Ensure no fabricated location stored in hazard_suggestions (schema has no location column)
        // and original report location unchanged
        $reportLoc = DB::selectOne('SELECT ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat FROM hazard_reports WHERE id = ?', [$reportId]);
        self::assertEqualsWithDelta(106.81, (float) $reportLoc->lng, 0.001);
        self::assertEqualsWithDelta(-6.20, (float) $reportLoc->lat, 0.001);
    }

    public function test_postgis_location_persisted_when_report_created(): void
    {
        $reportId = $this->createHazardReport('Test spatial');
        $row = DB::selectOne('SELECT ST_SRID(location) as srid, GeometryType(location::geometry) as gtype FROM hazard_reports WHERE id = ?', [$reportId]);
        self::assertSame(4326, (int) $row->srid);
        self::assertSame('POINT', $row->gtype);
    }
}
