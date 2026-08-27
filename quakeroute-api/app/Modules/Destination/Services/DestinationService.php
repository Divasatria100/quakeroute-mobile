<?php

declare(strict_types=1);

namespace App\Modules\Destination\Services;

use Illuminate\Support\Facades\DB;

final class DestinationService
{
    public function list(?array $bbox): array
    {
        $query = DB::table('destinations')->where('is_synthetic', false);
        if ($bbox !== null) {
            [$minLng, $minLat, $maxLng, $maxLat] = $bbox;
            $query->whereRaw('ST_Intersects(geom, ST_MakeEnvelope(?, ?, ?, ?, 4326)::geography)', [$minLng, $minLat, $maxLng, $maxLat]);
        }
        $rows = $query->get();
        $out = [];
        foreach ($rows as $row) {
            $loc = DB::selectOne('SELECT ST_X(geom::geometry) as lng, ST_Y(geom::geometry) as lat FROM destinations WHERE id = ?', [$row->id]);
            $out[] = [
                'destination_id' => $row->id,
                'name' => $row->name,
                'type' => $row->type,
                'location' => ['lat' => (float) $loc->lat, 'lng' => (float) $loc->lng],
            ];
        }

        return $out;
    }
}
