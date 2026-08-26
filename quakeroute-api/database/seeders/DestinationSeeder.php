<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DestinationSeeder extends Seeder
{
    public function run(): void
    {
        $destinations = [
            ['id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'name' => 'Shelter Balai Kota', 'type' => 'Shelter', 'lng' => 106.8005, 'lat' => -6.2005, 'nearest' => '11111111-1111-1111-1111-111111111111'],
            ['id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'name' => 'Shelter Pasar Minggu', 'type' => 'Shelter', 'lng' => 106.8205, 'lat' => -6.2005, 'nearest' => '33333333-3333-3333-3333-333333333333'],
            ['id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3', 'name' => 'Shelter F Community Hall', 'type' => 'Shelter', 'lng' => 106.8205, 'lat' => -6.2105, 'nearest' => '66666666-6666-6666-6666-666666666666'],
            ['id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4', 'name' => 'Medical Facility D', 'type' => 'MedicalFacility', 'lng' => 106.8005, 'lat' => -6.2105, 'nearest' => '44444444-4444-4444-4444-444444444444'],
            ['id' => 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb5', 'name' => 'Medical Facility B', 'type' => 'MedicalFacility', 'lng' => 106.8105, 'lat' => -6.2005, 'nearest' => '22222222-2222-2222-2222-222222222222'],
        ];

        foreach ($destinations as $d) {
            DB::table('destinations')->updateOrInsert(
                ['id' => $d['id']],
                [
                    'name' => $d['name'],
                    'type' => $d['type'],
                    'geom' => DB::raw("ST_GeogFromText('POINT({$d['lng']} {$d['lat']})')"),
                    'nearest_road_node_id' => $d['nearest'],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]
            );
        }
    }
}
