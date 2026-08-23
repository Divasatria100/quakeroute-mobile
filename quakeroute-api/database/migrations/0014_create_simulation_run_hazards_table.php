<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('simulation_run_hazards', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('simulation_run_id');
            $table->uuid('hazard_id');
            $table->foreign('simulation_run_id')->references('id')->on('simulation_runs')->onDelete('cascade');
            $table->foreign('hazard_id')->references('id')->on('hazards')->onDelete('cascade');
            $table->unique(['simulation_run_id', 'hazard_id']);
            $table->index('simulation_run_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('simulation_run_hazards');
    }
};
