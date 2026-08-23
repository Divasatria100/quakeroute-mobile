<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('road_segments', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('from_node_id');
            $table->uuid('to_node_id');
            $table->decimal('base_travel_cost', 10, 2);
            $table->decimal('length_m', 10, 2)->nullable();
            $table->boolean('bidirectional')->default(true);
            $table->timestampsTz();

            $table->foreign('from_node_id')->references('id')->on('road_nodes')->onDelete('cascade');
            $table->foreign('to_node_id')->references('id')->on('road_nodes')->onDelete('cascade');
        });

        DB::statement('ALTER TABLE road_segments ADD COLUMN geom geography(LineString, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_road_segments_geom ON road_segments USING GIST (geom)');
        DB::statement('CREATE INDEX idx_road_segments_from_node ON road_segments (from_node_id)');
        DB::statement('CREATE INDEX idx_road_segments_to_node ON road_segments (to_node_id)');

        DB::statement('ALTER TABLE road_segments ADD CONSTRAINT chk_road_segments_no_self_loop CHECK (from_node_id <> to_node_id)');
        DB::statement('ALTER TABLE road_segments ADD CONSTRAINT chk_road_segments_cost CHECK (base_travel_cost >= 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('road_segments');
    }
};
