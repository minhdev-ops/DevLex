<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('term_aliases', function (Blueprint $table) {
            $table->id();
            $table->string('term_id', 40);
            $table->string('alias', 100)->unique();
            $table->text('naming_rule_note')->nullable();
            $table->timestamps();

            $table->foreign('term_id')->references('id')->on('terms')->cascadeOnDelete();
            $table->index('alias');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('term_aliases');
    }
};
