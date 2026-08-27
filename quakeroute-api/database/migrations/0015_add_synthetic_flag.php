<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('road_nodes', function (Blueprint $table) {
            $table->boolean('is_synthetic')->default(false)->after('geom');
            $table->uuid('simulation_run_id')->nullable()->after('is_synthetic');
            $table->index('is_synthetic');
        });
        Schema::table('road_segments', function (Blueprint $table) {
            $table->boolean('is_synthetic')->default(false)->after('bidirectional');
            $table->uuid('simulation_run_id')->nullable()->after('is_synthetic');
            $table->index('is_synthetic');
        });
        Schema::table('destinations', function (Blueprint $table) {
            $table->boolean('is_synthetic')->default(false)->after('nearest_road_node_id');
            $table->uuid('simulation_run_id')->nullable()->after('is_synthetic');
            $table->index('is_synthetic');
        });
        // Make synthetic rows not affect global queries by default.
        // No change to existing data (all false).
    }

    public function down(): void
    {
        Schema::table('road_nodes', function (Blueprint $table) {
            $table->dropColumn(['is_synthetic', 'simulation_run_id']);
        });
        Schema::table('road_segments', function (Blueprint $table) {
            $table->dropColumn(['is_synthetic', 'simulation_run_id']);
        });
        Schema::table('destinations', function (Blueprint $table) {
            $table->dropColumn(['is_synthetic', 'simulation_run_id']);
        });
    }
};
