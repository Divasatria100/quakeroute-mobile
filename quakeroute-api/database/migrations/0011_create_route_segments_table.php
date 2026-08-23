<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('route_segments', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('route_id');
            $table->uuid('road_segment_id');
            $table->integer('sequence_order');
            $table->decimal('base_travel_cost', 10, 2);
            $table->decimal('hazard_penalty', 10, 2)->default(0);
            $table->decimal('uncertainty_penalty', 10, 2)->default(0);
            $table->decimal('segment_routing_cost', 10, 2);

            $table->foreign('route_id')->references('id')->on('routes')->onDelete('cascade');
            $table->foreign('road_segment_id')->references('id')->on('road_segments')->onDelete('cascade');
            $table->unique(['route_id', 'sequence_order']);
            $table->index(['route_id', 'sequence_order']);
            $table->index('road_segment_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('route_segments');
    }
};
