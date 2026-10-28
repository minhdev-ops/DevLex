<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('contributions', function (Blueprint $table) {
            $table->string('id', 40)->primary();          // c_xxx
            $table->foreignId('user_id')->nullable();      // null = khách vãng lai
            $table->string('contributor_name', 120);
            $table->string('tier_1_acronym', 100);
            $table->string('tier_1_full_name_en', 255);
            $table->text('tier_1_short_definition');
            $table->text('tier_2_detailed_explanation')->nullable();
            $table->string('status', 20)->default('pending');   // pending | approved | rejected
            $table->text('review_note')->nullable();
            $table->foreignId('reviewed_by')->nullable();        // id admin/moderator
            $table->string('term_id', 40)->nullable();           // liên kết term khi duyệt
            $table->timestamps();

            $table->index('status');
            $table->index('tier_1_acronym');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contributions');
    }
};
