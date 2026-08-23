<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('simulation_runs', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->string('scenario_key', 50);
            $table->uuid('destination_id');
            $table->string('status', 20)->default('Running');
            $table->uuid('baseline_route_id')->nullable();
            $table->uuid('risk_aware_route_id')->nullable();
            $table->timestampTz('started_at')->useCurrent();
            $table->timestampTz('completed_at')->nullable();

            $table->foreign('scenario_key')->references('scenario_key')->on('simulation_scenarios')->onDelete('cascade');
            $table->foreign('destination_id')->references('id')->on('destinations')->onDelete('cascade');
            $table->foreign('baseline_route_id')->references('id')->on('routes')->nullOnDelete();
            $table->foreign('risk_aware_route_id')->references('id')->on('routes')->nullOnDelete();
            $table->index('scenario_key');
            $table->index('status');
        });

        DB::statement('ALTER TABLE simulation_runs ADD COLUMN origin geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_simulation_runs_origin ON simulation_runs USING GIST (origin)');
        DB::statement("ALTER TABLE simulation_runs ADD CONSTRAINT chk_simulation_runs_status CHECK (status IN ('Running','Completed','Failed'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('simulation_runs');
    }
};
