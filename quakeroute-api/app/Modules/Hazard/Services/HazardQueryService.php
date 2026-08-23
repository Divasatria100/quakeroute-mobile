<?php

declare(strict_types=1);

namespace App\Modules\Hazard\Services;

use Illuminate\Support\Facades\DB;

final class HazardQueryService
{
    public function list(array $filters): array
    {
        $query = DB::table('hazards');

        if (isset($filters['status']) && $filters['status'] !== '') {
            $query->where('status', $filters['status']);
        }

        if (isset($filters['bbox']) && $filters['bbox'] !== null) {
            [$minLng, $minLat, $maxLng, $maxLat] = $filters['bbox'];
            $query->whereRaw('ST_Intersects(location, ST_MakeEnvelope(?, ?, ?, ?, 4326)::geography)', [$minLng, $minLat, $maxLng, $maxLat]);
        }

        if (isset($filters['updated_since']) && $filters['updated_since'] !== '') {
            $query->where('updated_at', '>=', $filters['updated_since']);
        }

        $rows = $query->orderBy('reported_at', 'desc')->limit(100)->get();

        $hazards = [];
        foreach ($rows as $row) {
            $loc = DB::selectOne('SELECT ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat FROM hazards WHERE id = ?', [$row->id]);
            $hazards[] = [
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
            ];
        }

        return $hazards;
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
