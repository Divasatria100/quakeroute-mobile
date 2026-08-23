<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('routes', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('user_id')->nullable();
            $table->uuid('destination_id');
            $table->string('status', 20)->default('Active');
            $table->uuid('supersedes_route_id')->nullable();
            $table->decimal('total_cost', 12, 2);
            $table->timestampTz('created_at')->useCurrent();
            $table->timestampTz('superseded_at')->nullable();

            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();
            $table->foreign('destination_id')->references('id')->on('destinations')->onDelete('cascade');
            $table->index(['user_id', 'status']);
            $table->index('destination_id');
        });

        DB::statement('ALTER TABLE routes ADD CONSTRAINT routes_supersedes_route_id_foreign FOREIGN KEY (supersedes_route_id) REFERENCES routes(id) ON DELETE SET NULL');
        DB::statement('ALTER TABLE routes ADD COLUMN origin geography(Point, 4326) NOT NULL');
        DB::statement('CREATE INDEX idx_routes_origin ON routes USING GIST (origin)');
        DB::statement("ALTER TABLE routes ADD CONSTRAINT chk_routes_status CHECK (status IN ('Active','Superseded'))");
        DB::statement('CREATE UNIQUE INDEX uniq_routes_user_active ON routes (user_id) WHERE status = \'Active\'');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS uniq_routes_user_active');
        Schema::dropIfExists('routes');
    }
};
