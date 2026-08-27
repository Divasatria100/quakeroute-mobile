<?php

declare(strict_types=1);

namespace App\Modules\Hazard\Services;

use Illuminate\Support\Facades\DB;

final class HazardQueryService
{
    public function list(array $filters): array
    {
        $query = DB::table('hazards as i');

        if (isset($filters['status']) && $filters['status'] !== '') {
            $query->where('i.status', $filters['status']);
        }

        if (isset($filters['bbox']) && $filters['bbox'] !== null) {
            [$minLng, $minLat, $maxLng, $maxLat] = $filters['bbox'];
            $query->whereRaw('ST_Intersects(i.location, ST_MakeEnvelope(?, ?, ?, ?, 4326)::geography)', [$minLng, $minLat, $maxLng, $maxLat]);
        }

        if (isset($filters['updated_since']) && $filters['updated_since'] !== '') {
            $query->where('i.updated_at', '>=', $filters['updated_since']);
        }

        // Exclude synthetic simulation hazards from global map.
        $query->whereRaw('(i.road_segment_id IS NULL OR i.road_segment_id NOT IN (SELECT id FROM road_segments WHERE is_synthetic = true))');

        $rows = $query->selectRaw('i.*, ST_X(i.location::geometry) AS lng, ST_Y(i.location::geometry) AS lat')
            ->orderBy('i.reported_at', 'desc')->limit(100)->get();

        return $rows->map(fn ($row) => [
            'hazard_id' => $row->id,
            'type' => $row->type,
            'severity' => $row->severity,
            'confidence' => (float) $row->confidence,
            'road_impact' => $row->road_impact,
            'status' => $row->status,
            'location' => ['lat' => (float) $row->lat, 'lng' => (float) $row->lng],
            'road_segment_id' => $row->road_segment_id,
            'source' => $row->source,
            'timestamp' => $row->reported_at,
        ])->all();
    }

    public function detail(string $hazardId): array
    {
        $row = DB::table('hazards')->where('id', $hazardId)->first();
        if ($row === null) {
            abort(404, 'Hazard not found');
        }
        $loc = DB::selectOne('SELECT ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat FROM hazards WHERE id = ?', [$hazardId]);
        $conflicts = DB::table('hazard_conflicts')
            ->where('hazard_id_a', $hazardId)
            ->orWhere('hazard_id_b', $hazardId)
            ->get()
            ->map(fn ($c) => $c->hazard_id_a === $hazardId ? $c->hazard_id_b : $c->hazard_id_a)
            ->all();

        $evidence = null;
        if ($row->evidence_photo_url !== null) {
            $evidence = ['photo_url' => $row->evidence_photo_url];
        } elseif ($row->evidence_text !== null) {
            $evidence = ['text' => $row->evidence_text];
        }

        return [
            'hazard_id' => $row->id,
            'type' => $row->type,
            'severity' => $row->severity,
            'confidence' => (float) $row->confidence,
            'road_impact' => $row->road_impact,
            'status' => $row->status,
            'location' => ['lat' => (float) $loc->lat, 'lng' => (float) $loc->lng],
            'road_segment_id' => $row->road_segment_id,
            'source' => $row->source,
            'timestamp' => $row->reported_at,
            'evidence' => $evidence,
            'conflicting_with' => $conflicts,
        ];
    }
}
