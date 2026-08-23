<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hazard_reports', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('user_id')->nullable();
            $table->string('mode', 20);
            $table->text('raw_text')->nullable();
            $table->string('photo_url', 500)->nullable();
            $table->string('audio_url', 500)->nullable();
            $table->text('note')->nullable();
            $table->timestampTz('created_at')->useCurrent();
            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();
            $table->index('mode');
            $table->index('created_at');
        });

        DB::statement('ALTER TABLE hazard_reports ADD COLUMN location geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_hazard_reports_location ON hazard_reports USING GIST (location)');
        DB::statement("ALTER TABLE hazard_reports ADD CONSTRAINT chk_hazard_reports_mode CHECK (mode IN ('Photo','Text','QuickTap','Voice'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('hazard_reports');
    }
};
