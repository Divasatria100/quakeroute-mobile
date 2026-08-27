<?php

declare(strict_types=1);

namespace App\Modules\Hazard\Services;

use App\Modules\Route\Services\RouteRecalculationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class HazardSuggestionService
{
    public function __construct(
        private readonly RouteRecalculationService $recalculationService,
    ) {}

    public function confirm(string $suggestionId, ?array $edits): array
    {
        return DB::transaction(function () use ($suggestionId, $edits) {
            $suggestion = DB::table('hazard_suggestions')->where('id', $suggestionId)->first();
            if ($suggestion === null) {
                abort(404, 'Suggestion not found');
            }
            if ($suggestion->status !== 'PendingConfirmation') {
                abort(409, 'Suggestion already resolved');
            }

            $type = $edits['type'] ?? $suggestion->proposed_type;
            $severity = $edits['severity'] ?? $suggestion->proposed_severity;
            $roadImpact = $edits['road_impact'] ?? $suggestion->proposed_road_impact;
            $confidence = $suggestion->proposed_confidence;

            // Validate against allowed enums (reuse validator logic)
            $allowedTypes = ['DebrisRubble', 'RoadBlockage', 'Fire', 'Flood', 'ElectricalHazard', 'VisibleBuildingDamage'];
            $allowedSeverities = ['Low', 'Medium', 'High'];
            $allowedImpacts = ['Passable', 'PartiallyBlocked', 'Blocked'];

            if (! in_array($type, $allowedTypes, true) || ! in_array($severity, $allowedSeverities, true) || ! in_array($roadImpact, $allowedImpacts, true)) {
                abort(422, 'Invalid edits enum value');
            }

            $report = DB::table('hazard_reports')->where('id', $suggestion->hazard_report_id)->first();
            $locationRow = DB::selectOne('SELECT ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat FROM hazard_reports WHERE id = ?', [$report->id]);
            $location = ['lat' => (float) $locationRow->lat, 'lng' => (float) $locationRow->lng];
            $roadSegmentId = $this->resolveNearestSegment($location);

            $hazardId = (string) Str::uuid();
            DB::table('hazards')->insert([
                'id' => $hazardId,
                'hazard_report_id' => $report->id,
                'hazard_suggestion_id' => $suggestionId,
                'type' => $type,
                'severity' => $severity,
                'confidence' => $confidence,
                'road_impact' => $roadImpact,
                'status' => 'Reported',
                'source' => 'AIVisionPhoto',
                'location' => DB::raw("ST_GeogFromText('POINT({$location['lng']} {$location['lat']})')"),
                'road_segment_id' => $roadSegmentId,
                'evidence_photo_url' => $report->photo_url,
                'evidence_text' => null,
                'reported_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('hazard_suggestions')->where('id', $suggestionId)->update([
                'status' => 'Confirmed',
                'resulting_hazard_id' => $hazardId,
                'resolved_at' => now(),
            ]);

            if ($roadSegmentId !== null) {
                $this->recalculationService->recalculateForAffectedSegment($roadSegmentId);
            }

            return [
                'hazard_id' => $hazardId,
                'status' => 'Reported',
                'type' => $type,
                'severity' => $severity,
                'confidence' => (float) $confidence,
                'road_impact' => $roadImpact,
                'location' => $location,
                'source' => 'AIVisionPhoto',
                'timestamp' => now()->toIso8601String(),
                'evidence' => ['photo_url' => $report->photo_url],
            ];
        });
    }

    public function reject(string $suggestionId): array
    {
        return DB::transaction(function () use ($suggestionId) {
            $suggestion = DB::table('hazard_suggestions')->where('id', $suggestionId)->first();
            if ($suggestion === null) {
                abort(404, 'Suggestion not found');
            }
            if ($suggestion->status !== 'PendingConfirmation') {
                abort(409, 'Suggestion already resolved');
            }

            DB::table('hazard_suggestions')->where('id', $suggestionId)->update([
                'status' => 'Rejected',
                'resolved_at' => now(),
            ]);

            return ['suggestion_id' => $suggestionId, 'status' => 'Rejected'];
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
