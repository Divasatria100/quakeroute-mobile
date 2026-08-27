<?php

declare(strict_types=1);

namespace App\Modules\Simulation\Support;

use Random\Engine\Mt19937;
use Random\Randomizer;

final class SyntheticNetworkGenerator
{
    /**
     * Generate a deterministic synthetic grid around a center.
     *
     * @return array{nodes: array<int, array{id: string, lat: float, lng: float, label: string}>, segments: array<int, array{id: string, from: string, to: string, wkt: string, base_cost: float, bidirectional: bool}>, destinations: array<int, array{id: string, name: string, type: string, lat: float, lng: float}>}
     */
    public function generate(float $centerLat, float $centerLng, int $seed, int $radiusM = 1500): array
    {
        $rand = new Randomizer(new Mt19937($seed));

        // 4x4 grid = 16 nodes, spacing ~ radius*0.45
        $cols = 4;
        $rows = 4;
        $span = $radiusM * 1.2; // diameter-ish
        $spacingX = $span / ($cols - 1);
        $spacingY = $span / ($rows - 1);

        $nodes = [];
        $nodeIds = [];
        $nodeCoords = []; // id => [lat,lng]

        $labels = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P'];

        for ($r = 0; $r < $rows; $r++) {
            for ($c = 0; $c < $cols; $c++) {
                $idx = $r * $cols + $c;
                $offX = ($c - ($cols - 1) / 2) * $spacingX;
                $offY = ($r - ($rows - 1) / 2) * $spacingY;
                // jitter +- 25m
                $offX += $rand->getInt(-25, 25);
                $offY += $rand->getInt(-25, 25);

                [$dLat, $dLng] = $this->metersToDegrees($offY, $offX, $centerLat);
                $lat = $centerLat + $dLat;
                $lng = $centerLng + $dLng;
                $id = $this->deterministicUuid($seed, 'node', $idx, $centerLat, $centerLng);
                $nodes[] = ['id' => $id, 'lat' => $lat, 'lng' => $lng, 'label' => $labels[$idx] ?? (string)$idx];
                $nodeIds[] = $id;
                $nodeCoords[$id] = [$lat, $lng];
            }
        }

        // Helper to get node id by row/col
        $nid = function (int $r, int $c) use ($cols, $seed, $centerLat, $centerLng): string {
            return $this->deterministicUuid($seed, 'node', $r * $cols + $c, $centerLat, $centerLng);
        };

        $segments = [];
        $segIdx = 0;
        $addSeg = function (string $from, string $to) use (&$segments, &$segIdx, $seed, $centerLat, $centerLng, $nodeCoords) {
            $id = $this->deterministicUuid($seed, 'seg', $segIdx++, $centerLat, $centerLng);
            [$lat1, $lng1] = $nodeCoords[$from];
            [$lat2, $lng2] = $nodeCoords[$to];
            $wkt = sprintf('LINESTRING(%F %F, %F %F)', $lng1, $lat1, $lng2, $lat2);
            $segments[] = ['id' => $id, 'from' => $from, 'to' => $to, 'wkt' => $wkt, 'base_cost' => 10.0, 'bidirectional' => true];
        };

        // Horizontal edges
        for ($r = 0; $r < $rows; $r++) {
            for ($c = 0; $c < $cols - 1; $c++) {
                $addSeg($nid($r, $c), $nid($r, $c + 1));
            }
        }
        // Vertical edges
        for ($c = 0; $c < $cols; $c++) {
            for ($r = 0; $r < $rows - 1; $r++) {
                $addSeg($nid($r, $c), $nid($r + 1, $c));
            }
        }
        // Add 2-4 diagonal/cross edges for alternatives (seeded)
        $extra = $rand->getInt(2, 4);
        for ($i = 0; $i < $extra; $i++) {
            $r = $rand->getInt(0, $rows - 2);
            $c = $rand->getInt(0, $cols - 2);
            // randomly choose diagonal direction
            if ($rand->getInt(0, 1) === 0) {
                $addSeg($nid($r, $c), $nid($r + 1, $c + 1));
            } else {
                $addSeg($nid($r, $c + 1), $nid($r + 1, $c));
            }
        }

        // Optionally remove 1-2 random edges to create dead-ends (but keep connectivity by not removing bridge)
        // For MVP keep all for determinism.

        // Destinations: 4 around corners + 1 near center-east
        $destOffsets = [
            ['name' => 'Shelter North-West', 'type' => 'Shelter', 'dx' => -$radiusM * 0.7, 'dy' => $radiusM * 0.7],
            ['name' => 'Shelter South-East', 'type' => 'Shelter', 'dx' => $radiusM * 0.7, 'dy' => -$radiusM * 0.7],
            ['name' => 'Medical North-East', 'type' => 'MedicalFacility', 'dx' => $radiusM * 0.6, 'dy' => $radiusM * 0.6],
            ['name' => 'Medical South-West', 'type' => 'MedicalFacility', 'dx' => -$radiusM * 0.6, 'dy' => -$radiusM * 0.6],
            ['name' => 'Shelter Central East', 'type' => 'Shelter', 'dx' => $radiusM * 0.5, 'dy' => 0],
        ];
        $destinations = [];
        foreach ($destOffsets as $idx => $off) {
            [$dLat, $dLng] = $this->metersToDegrees($off['dy'], $off['dx'], $centerLat);
            $destinations[] = [
                'id' => $this->deterministicUuid($seed, 'dest', $idx, $centerLat, $centerLng),
                'name' => $off['name'],
                'type' => $off['type'],
                'lat' => $centerLat + $dLat,
                'lng' => $centerLng + $dLng,
            ];
        }

        return ['nodes' => $nodes, 'segments' => $segments, 'destinations' => $destinations, 'nodeCoords' => $nodeCoords];
    }

    /**
     * Convert meters offset to degrees.
     *
     * @return array{0: float, 1: float} [dLat, dLng]
     */
    private function metersToDegrees(float $dy, float $dx, float $centerLat): array
    {
        $dLat = $dy / 111000.0;
        $cos = cos(deg2rad($centerLat));
        if (abs($cos) < 0.01) $cos = 0.01;
        $dLng = $dx / (111000.0 * $cos);
        return [$dLat, $dLng];
    }

    private function deterministicUuid(int $seed, string $prefix, int $idx, ?float $centerLat = null, ?float $centerLng = null): string
    {
        $key = $seed . '-' . $prefix . '-' . $idx;
        if ($centerLat !== null && $centerLng !== null) {
            $key .= '-' . round($centerLat, 5) . '-' . round($centerLng, 5);
        }
        $hash = md5($key);
        return sprintf('%s-%s-%s-%s-%s', substr($hash, 0, 8), substr($hash, 8, 4), substr($hash, 12, 4), substr($hash, 16, 4), substr($hash, 20, 12));
    }
}
