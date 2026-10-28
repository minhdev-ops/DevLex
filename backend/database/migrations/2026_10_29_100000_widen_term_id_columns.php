<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Tên slug của NIST dài hơn 40 ký tự (ví dụ
 * "nist_american-registry-for-internet-numbers" = 43), id quá cỡ làm cả đợt quệt
 * 10.400 slug chết giữa chừng. Nới các cột id sang varchar(64).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('term_aliases', function (Blueprint $table): void {
            $table->dropForeign('term_aliases_term_id_foreign');
        });

        DB::statement('alter table `terms` modify `id` varchar(64) not null');
        DB::statement('alter table `term_aliases` modify `term_id` varchar(64) not null');
        DB::statement('alter table `contributions` modify `term_id` varchar(64) null');

        Schema::table('term_aliases', function (Blueprint $table): void {
            $table->foreign('term_id')->references('id')->on('terms')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('term_aliases', function (Blueprint $table): void {
            $table->dropForeign('term_aliases_term_id_foreign');
        });

        DB::statement('alter table `terms` modify `id` varchar(40) not null');
        DB::statement('alter table `term_aliases` modify `term_id` varchar(40) not null');
        DB::statement('alter table `contributions` modify `term_id` varchar(40) null');

        Schema::table('term_aliases', function (Blueprint $table): void {
            $table->foreign('term_id')->references('id')->on('terms')->cascadeOnDelete();
        });
    }
};
