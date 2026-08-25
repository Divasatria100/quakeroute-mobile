<?php

declare(strict_types=1);

namespace App\Modules\Route\Services;

use Illuminate\Support\Facades\DB;

final class RouteGeometryService
{
    /**
     * Build GeoJSON LineString for a route by merging its road_segments in sequence_order.
     *
     * Single query for all segments, preserves order, handles reversed traversal
     * by checking from/to node chain continuity.
     *
     * @return array{type: string, coordinates: array<int, array{0: float, 1: float}>}|null
     */
    public function getGeometry(string $routeId): ?array
    {
        $rows = DB::table('route_segments as rs')
            ->join('road_segments as seg', 'seg.id', '=', 'rs.road_segment_id')
            ->where('rs.route_id', $routeId)
            ->orderBy('rs.sequence_order')
            ->selectRaw('seg.id as seg_id, seg.from_node_id, seg.to_node_id, ST_AsGeoJSON(seg.geom::geometry) as geojson')
            ->get();

        if ($rows->isEmpty()) {
            return null;
        }

        // Need chain orientation: walk segments using from/to continuity
        $coords = [];
        $prevNode = null;
        $first = true;

        foreach ($rows as $row) {
            /** @var string $geojson */
            $geojson = $row->geojson;
            $decoded = json_decode($geojson, true);
            if (! is_array($decoded) || ! isset($decoded['coordinates']) || ! is_array($decoded['coordinates'])) {
                continue;
            }
            $segCoords = $decoded['coordinates']; // [[lng,lat],...] already GeoJSON order

            if ($first) {
                // First segment: keep as stored (from->to). Subsequent will orient via chain.
                // Detect if we need to reverse by checking next segment connectivity?
                // Instead, trust stored orientation for first, then orient next segments to continue chain.
                $coords = $segCoords;
                $prevNode = $row->to_node_id;
                // Determine if next segment connects to to_node; if not but connects to from_node, reverse first
                // Look ahead one segment if exists
                $next = $rows->get(1);
                if ($next !== null) {
                    $connectsToTo = $next->from_node_id === $row->to_node_id || $next->to_node_id === $row->to_node_id;
                    $connectsToFrom = $next->from_node_id === $row->from_node_id || $next->to_node_id === $row->from_node_id;
                    if (! $connectsToTo && $connectsToFrom) {
                        $coords = array_reverse($segCoords);
                        $prevNode = $row->from_node_id;
                    }
                }
                $first = false;

                continue;
            }

            // Orient current segment so its start matches prevNode
            $from = $row->from_node_id;
            $to = $row->to_node_id;
            if ($from !== $prevNode && $to === $prevNode) {
                $segCoords = array_reverse($segCoords);
                $prevNode = $from;
            } elseif ($from === $prevNode) {
                $prevNode = $to;
            } elseif ($to === $prevNode) {
                // already handled above but keep for clarity
                $segCoords = array_reverse($segCoords);
                $prevNode = $from;
            } else {
                // Disconnected chain (should not happen) - just append
                $prevNode = $to;
            }

            // Deduplicate joint point (within tiny epsilon)
            if ($coords !== [] && $segCoords !== []) {
                $last = $coords[count($coords) - 1];
                $firstOfSeg = $segCoords[0];
                if (abs($last[0] - $firstOfSeg[0]) < 1e-9 && abs($last[1] - $firstOfSeg[1]) < 1e-9) {
                    array_shift($segCoords);
                }
            }

            $coords = array_merge($coords, $segCoords);
        }

        if ($coords === []) {
            return null;
        }

        return [
            'type' => 'LineString',
            'coordinates' => $coords,
        ];
    }
}
