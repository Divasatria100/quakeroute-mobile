<?php

declare(strict_types=1);

namespace App\Modules\Hazard\Services;

use App\Modules\AI\Services\HazardUnderstandingService;
use App\Modules\AI\Support\AIProviderException;
use App\Modules\Route\Services\RouteRecalculationService;
use App\Modules\Shared\Support\SessionHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class HazardReportService
{
    public function __construct(
        private readonly HazardUnderstandingService $hazardUnderstandingService,
        private readonly RouteRecalculationService $recalculationService,
    ) {}

    public function createPhotoReport(Request $request, string $photoUrl, array $location, ?string $note): array
    {
        return DB::transaction(function () use ($request, $photoUrl, $location, $note) {
            $userId = SessionHelper::getOrCreateUserId($request);
            $reportId = (string) Str::uuid();

            DB::table('hazard_reports')->insert([
                'id' => $reportId,
                'user_id' => $userId,
                'mode' => 'Photo',
                'raw_text' => $note,
                'photo_url' => $photoUrl,
                'audio_url' => null,
                'note' => $note,
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'created_at' => now(),
            ]);

            // Run AI - use note as report text, or fallback
            $textForAI = $note ?? 'photo hazard report';
            // Temporarily update raw_text for AI if note empty
            if ($note === null || $note === '') {
                DB::table('hazard_reports')->where('id', $reportId)->update(['raw_text' => $textForAI]);
            }

            $result = $this->hazardUnderstandingService->processReport($reportId);

            if (! $result['success']) {
                // AI failure - still return suggestion as failed, per spec return 502/503 handling in controller
                throw new AIProviderException($result['error'] ?? 'AI failed', 0, null, 'unavailable');
            }

            $suggestion = DB::table('hazard_suggestions')->where('id', $result['suggestionId'])->first();

            return [
                'suggestion_id' => $suggestion->id,
                'status' => $suggestion->status,
                'proposed_hazard' => [
                    'type' => $suggestion->proposed_type,
                    'severity' => $suggestion->proposed_severity,
                    'confidence' => (float) $suggestion->proposed_confidence,
                    'road_impact' => $suggestion->proposed_road_impact,
                    'location' => $location,
                    'evidence' => ['photo_url' => $photoUrl],
                    'source' => 'AIVisionPhoto',
                ],
            ];
        });
    }

    public function createTextReport(Request $request, string $text, array $location): array
    {
        return DB::transaction(function () use ($request, $text, $location) {
            $userId = SessionHelper::getOrCreateUserId($request);
            $reportId = (string) Str::uuid();

            DB::table('hazard_reports')->insert([
                'id' => $reportId,
                'user_id' => $userId,
                'mode' => 'Text',
                'raw_text' => $text,
                'photo_url' => null,
                'audio_url' => null,
                'note' => null,
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'created_at' => now(),
            ]);

            $result = $this->hazardUnderstandingService->processReport($reportId);

            if (! $result['success']) {
                // Per spec, AI failure for text should result in 502 and no hazards, but we throw to let controller handle
                throw new AIProviderException($result['error'] ?? 'AI failed', 0, null, 'unavailable');
            }

            // For text, directly create hazard (per spec)
            $dto = $result['dto'];
            $hazardId = (string) Str::uuid();
            $roadSegmentId = $this->resolveNearestSegment($location);

            DB::table('hazards')->insert([
                'id' => $hazardId,
                'hazard_report_id' => $reportId,
                'hazard_suggestion_id' => null,
                'type' => $dto->type,
                'severity' => $dto->severity,
                'confidence' => $dto->confidence,
                'road_impact' => $dto->roadImpact,
                'status' => 'Reported',
                'source' => 'AITextExtraction',
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'road_segment_id' => $roadSegmentId,
                'evidence_photo_url' => null,
                'evidence_text' => $text,
                'reported_at' => now(),
                'updated_at' => now(),
            ]);

            if ($roadSegmentId !== null) {
                $this->recalculationService->recalculateForAffectedSegment($roadSegmentId);
            }

            return [
                'hazards' => [
                    [
                        'hazard_id' => $hazardId,
                        'status' => 'Reported',
                        'type' => $dto->type,
                        'severity' => $dto->severity,
                        'confidence' => $dto->confidence,
                        'road_impact' => $dto->roadImpact,
                        'location' => $location,
                        'source' => 'AITextExtraction',
                        'timestamp' => now()->toIso8601String(),
                        'evidence' => ['text' => $text],
                    ],
                ],
            ];
        });
    }

    public function createQuickReport(Request $request, string $type, array $location): array
    {
        return DB::transaction(function () use ($request, $type, $location) {
            $userId = SessionHelper::getOrCreateUserId($request);
            $reportId = (string) Str::uuid();

            DB::table('hazard_reports')->insert([
                'id' => $reportId,
                'user_id' => $userId,
                'mode' => 'QuickTap',
                'raw_text' => null,
                'photo_url' => null,
                'audio_url' => null,
                'note' => null,
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'created_at' => now(),
            ]);

            // MVP defaults for quick report (TBD in docs, config-driven assumption)
            $severity = 'Medium';
            $confidence = 0.6;
            $roadImpact = 'PartiallyBlocked';
            $hazardId = (string) Str::uuid();
            $roadSegmentId = $this->resolveNearestSegment($location);

            DB::table('hazards')->insert([
                'id' => $hazardId,
                'hazard_report_id' => $reportId,
                'hazard_suggestion_id' => null,
                'type' => $type,
                'severity' => $severity,
                'confidence' => $confidence,
                'road_impact' => $roadImpact,
                'status' => 'Reported',
                'source' => 'QuickTap',
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'road_segment_id' => $roadSegmentId,
                'evidence_photo_url' => null,
                'evidence_text' => null,
                'reported_at' => now(),
                'updated_at' => now(),
            ]);

            if ($roadSegmentId !== null) {
                $this->recalculationService->recalculateForAffectedSegment($roadSegmentId);
            }

            return [
                'hazard_id' => $hazardId,
                'status' => 'Reported',
                'type' => $type,
                'severity' => $severity,
                'confidence' => $confidence,
                'road_impact' => $roadImpact,
                'location' => $location,
                'source' => 'QuickTap',
                'timestamp' => now()->toIso8601String(),
                'evidence' => null,
            ];
        });
    }

    private function resolveNearestSegment(array $location): ?string
    {
        $lng = $location['lng'];
        $lat = $location['lat'];
        $result = DB::selectOne("SELECT id FROM road_segments ORDER BY geom <-> ST_GeogFromText('POINT($lng $lat)') LIMIT 1");

        return $result?->id;
    }
}
