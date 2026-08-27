<?php

declare(strict_types=1);

namespace App\Modules\Road\Services;

use Illuminate\Support\Facades\DB;

final class RoadSegmentService
{
    /**
     * List road segments with geometry and derived condition.
     *
     * @return array<int, array{id: string, geometry: array{type: string, coordinates: array}, condition: string, base_travel_cost: float}>
     */
    public function list(?array $bbox = null): array
    {
        // Single query for segments + geometry
        $query = DB::table('road_segments')->where('is_synthetic', false)
            ->selectRaw('id, base_travel_cost, ST_AsGeoJSON(geom::geometry) as geojson');

        // Optional bbox filter using ST_Intersects if provided [minLng,minLat,maxLng,maxLat]
        if ($bbox !== null && count($bbox) === 4) {
            [$minLng, $minLat, $maxLng, $maxLat] = $bbox;
            $query->whereRaw(
                'ST_Intersects(geom::geometry, ST_MakeEnvelope(?, ?, ?, ?, 4326))',
                [$minLng, $minLat, $maxLng, $maxLat]
            );
        }

        $segments = $query->get();

        // Batch load hazards grouped by road_segment_id
        $hazardsBySegment = DB::table('hazards')
            ->select('road_segment_id', 'severity', 'road_impact', 'status')
            ->whereNotNull('road_segment_id')
            ->get()
            ->groupBy('road_segment_id');

        $data = [];
        foreach ($segments as $seg) {
            $geojson = $seg->geojson;
            if ($geojson === null) {
                continue;
            }
            $decoded = json_decode($geojson, true);
            if (! is_array($decoded) || ! isset($decoded['coordinates'])) {
                continue;
            }
            $hazards = $hazardsBySegment->get($seg->id, collect())->toArray();
            $condition = $this->deriveCondition($hazards);

            $data[] = [
                'id' => $seg->id,
                'geometry' => [
                    'type' => $decoded['type'] ?? 'LineString',
                    'coordinates' => $decoded['coordinates'],
                ],
                'condition' => $condition,
                'base_travel_cost' => (float) $seg->base_travel_cost,
            ];
        }

        return $data;
    }

    /**
     * @param  array<int, object{severity: string, road_impact: string, status: string}>  $hazards
     */
    private function deriveCondition(array $hazards): string
    {
        if ($hazards === []) {
            return 'Safe';
        }

        $hasUncertain = false;
        $hasBlocked = false;
        $maxSeverityRank = 0; // Low=1, Medium=2, High=3
        $severityRank = ['Low' => 1, 'Medium' => 2, 'High' => 3];

        foreach ($hazards as $h) {
            $status = is_array($h) ? $h['status'] : $h->status;
            $impact = is_array($h) ? $h['road_impact'] : $h->road_impact;
            $sev = is_array($h) ? $h['severity'] : $h->severity;
            if ($status === 'UncertainConflicting' || $status === 'Reported') {
                $hasUncertain = true;
            }
            if ($impact === 'Blocked') {
                $hasBlocked = true;
            }
            $rank = $severityRank[$sev] ?? 0;
            if ($rank > $maxSeverityRank) {
                $maxSeverityRank = $rank;
            }
        }

        if ($hasBlocked) {
            return 'Critical';
        }
        if ($hasUncertain) {
            return 'Uncertain';
        }
        if ($maxSeverityRank === 3) {
            return 'Danger';
        }
        if ($maxSeverityRank === 2) {
            return 'Warning';
        }

        return 'Info';
    }
}
