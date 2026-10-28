<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('terms', function (Blueprint $table) {
            $table->string('id', 40)->primary();
            $table->string('tier_1_acronym', 100);
            $table->string('tier_1_full_name_en', 255);
            $table->string('tier_1_full_name_vi', 255);
            $table->text('tier_1_short_definition');
            $table->text('tier_2_detailed_explanation')->nullable();
            $table->text('tier_2_metaphor_analogy')->nullable();
            $table->string('tier_2_diagram_url')->nullable();
            $table->json('tier_3_category_tags')->default('[]');
            $table->string('tier_3_difficulty_level', 20)->default('Beginner');
            $table->json('tier_3_prerequisites')->nullable();
            $table->json('tier_3_related_terms')->nullable();
            $table->string('roadmap_career', 30)->nullable();
            $table->json('source_attribution')->default('[]');
            $table->timestamps();

            $table->index('tier_1_acronym');
            $table->index('tier_1_full_name_en');
            $table->index('roadmap_career');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('terms');
    }
};
