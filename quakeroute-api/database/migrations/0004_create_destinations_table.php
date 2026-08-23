<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('destinations', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->string('name', 255);
            $table->string('type', 20);
            $table->uuid('nearest_road_node_id')->nullable();
            $table->timestampsTz();

            $table->foreign('nearest_road_node_id')->references('id')->on('road_nodes')->nullOnDelete();
            $table->index('type');
        });

        DB::statement('ALTER TABLE destinations ADD COLUMN geom geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_destinations_geom ON destinations USING GIST (geom)');
        DB::statement("ALTER TABLE destinations ADD CONSTRAINT chk_destinations_type CHECK (type IN ('Shelter','MedicalFacility'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('destinations');
    }
};
