<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('road_nodes', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->string('label', 255)->nullable();
            $table->timestampsTz();
        });

        DB::statement('ALTER TABLE road_nodes ADD COLUMN geom geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_road_nodes_geom ON road_nodes USING GIST (geom)');
    }

    public function down(): void
    {
        Schema::dropIfExists('road_nodes');
    }
};
