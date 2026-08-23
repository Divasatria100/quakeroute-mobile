<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('hazard_suggestions', function (Blueprint $table) {
            $table->foreign('resulting_hazard_id')->references('id')->on('hazards')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('hazard_suggestions', function (Blueprint $table) {
            $table->dropForeign(['resulting_hazard_id']);
        });
    }
};
