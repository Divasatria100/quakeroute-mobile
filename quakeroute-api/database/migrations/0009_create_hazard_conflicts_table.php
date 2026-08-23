<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hazard_conflicts', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('hazard_id_a');
            $table->uuid('hazard_id_b');
            $table->timestampTz('detected_at')->useCurrent();

            $table->foreign('hazard_id_a')->references('id')->on('hazards')->onDelete('cascade');
            $table->foreign('hazard_id_b')->references('id')->on('hazards')->onDelete('cascade');
            $table->unique(['hazard_id_a', 'hazard_id_b']);
            $table->index('hazard_id_a');
            $table->index('hazard_id_b');
        });

        DB::statement('ALTER TABLE hazard_conflicts ADD CONSTRAINT chk_hazard_conflicts_not_same CHECK (hazard_id_a <> hazard_id_b)');
        DB::statement('ALTER TABLE hazard_conflicts ADD CONSTRAINT chk_hazard_conflicts_order CHECK (hazard_id_a < hazard_id_b)');
    }

    public function down(): void
    {
        Schema::dropIfExists('hazard_conflicts');
    }
};
