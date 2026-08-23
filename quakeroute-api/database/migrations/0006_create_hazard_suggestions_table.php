<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hazard_suggestions', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('hazard_report_id');
            $table->string('status', 20)->default('PendingConfirmation');
            $table->string('proposed_type', 30);
            $table->string('proposed_severity', 10);
            $table->decimal('proposed_confidence', 4, 3);
            $table->string('proposed_road_impact', 20);
            $table->uuid('resulting_hazard_id')->nullable();
            $table->timestampTz('created_at')->useCurrent();
            $table->timestampTz('resolved_at')->nullable();

            $table->foreign('hazard_report_id')->references('id')->on('hazard_reports')->onDelete('cascade');
            $table->index('status');
            $table->index('hazard_report_id');
        });

        DB::statement("ALTER TABLE hazard_suggestions ADD CONSTRAINT chk_hazard_suggestions_status CHECK (status IN ('PendingConfirmation','Confirmed','Rejected'))");
        DB::statement("ALTER TABLE hazard_suggestions ADD CONSTRAINT chk_hazard_suggestions_type CHECK (proposed_type IN ('DebrisRubble','RoadBlockage','Fire','Flood','ElectricalHazard','VisibleBuildingDamage'))");
        DB::statement("ALTER TABLE hazard_suggestions ADD CONSTRAINT chk_hazard_suggestions_severity CHECK (proposed_severity IN ('Low','Medium','High'))");
        DB::statement("ALTER TABLE hazard_suggestions ADD CONSTRAINT chk_hazard_suggestions_road_impact CHECK (proposed_road_impact IN ('Passable','PartiallyBlocked','Blocked'))");
        DB::statement('ALTER TABLE hazard_suggestions ADD CONSTRAINT chk_hazard_suggestions_confidence CHECK (proposed_confidence BETWEEN 0 AND 1)');
        // FK to hazards (resulting_hazard_id) deferred to 0008 to break circular dependency
    }

    public function down(): void
    {
        Schema::dropIfExists('hazard_suggestions');
    }
};
