<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hazards', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('hazard_report_id')->nullable();
            $table->uuid('hazard_suggestion_id')->nullable();
            $table->string('type', 30);
            $table->string('severity', 10);
            $table->decimal('confidence', 4, 3);
            $table->string('road_impact', 20);
            $table->string('status', 30)->default('Reported');
            $table->string('source', 30);
            $table->uuid('road_segment_id')->nullable();
            $table->string('evidence_photo_url', 500)->nullable();
            $table->text('evidence_text')->nullable();
            $table->timestampTz('reported_at')->useCurrent();
            $table->timestampTz('updated_at')->useCurrent();

            $table->foreign('hazard_report_id')->references('id')->on('hazard_reports')->nullOnDelete();
            $table->foreign('hazard_suggestion_id')->references('id')->on('hazard_suggestions')->nullOnDelete();
            $table->foreign('road_segment_id')->references('id')->on('road_segments')->nullOnDelete();
        });

        DB::statement('ALTER TABLE hazards ADD COLUMN location geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_hazards_location ON hazards USING GIST (location)');
        DB::statement('CREATE INDEX idx_hazards_road_segment ON hazards (road_segment_id)');
        DB::statement('CREATE INDEX idx_hazards_status ON hazards (status)');
        DB::statement('CREATE INDEX idx_hazards_type ON hazards (type)');
        DB::statement('CREATE INDEX idx_hazards_updated ON hazards (updated_at)');

        DB::statement("ALTER TABLE hazards ADD CONSTRAINT chk_hazards_type CHECK (type IN ('DebrisRubble','RoadBlockage','Fire','Flood','ElectricalHazard','VisibleBuildingDamage'))");
        DB::statement("ALTER TABLE hazards ADD CONSTRAINT chk_hazards_severity CHECK (severity IN ('Low','Medium','High'))");
        DB::statement("ALTER TABLE hazards ADD CONSTRAINT chk_hazards_road_impact CHECK (road_impact IN ('Passable','PartiallyBlocked','Blocked'))");
        DB::statement("ALTER TABLE hazards ADD CONSTRAINT chk_hazards_status CHECK (status IN ('Reported','Confirmed','UncertainConflicting'))");
        DB::statement("ALTER TABLE hazards ADD CONSTRAINT chk_hazards_source CHECK (source IN ('AIVisionPhoto','AITextExtraction','QuickTap','AIVoiceExtraction'))");
        DB::statement('ALTER TABLE hazards ADD CONSTRAINT chk_hazards_confidence CHECK (confidence BETWEEN 0 AND 1)');
    }

    public function down(): void
    {
        Schema::dropIfExists('hazards');
    }
};
