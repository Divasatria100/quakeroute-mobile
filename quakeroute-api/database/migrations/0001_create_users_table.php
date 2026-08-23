<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->string('session_id', 128)->unique();
            $table->string('device_id', 128)->nullable();
            $table->timestampsTz();
            $table->timestampTz('last_seen_at')->useCurrent();
        });

        DB::statement('CREATE INDEX idx_users_session_id ON users (session_id)');
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
