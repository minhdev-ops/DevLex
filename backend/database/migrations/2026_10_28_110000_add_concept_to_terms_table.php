<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * SRS mục 4 (giai đoạn 2 issue #8): cùng một khái niệm có thể có nhiều định
     * nghĩa theo ngữ cảnh (NIST = bảo mật, MDN = web). Thay vì gộp mất ngữ cảnh,
     * các mục từ được nối bằng khóa `concept` để API trả đủ các ngữ cảnh song song.
     */
    public function up(): void
    {
        Schema::table('terms', function (Blueprint $table) {
            $table->string('concept', 64)->nullable()->after('tier_1_full_name_vi');
            $table->index('concept');
        });
    }

    public function down(): void
    {
        Schema::table('terms', function (Blueprint $table) {
            $table->dropIndex(['concept']);
            $table->dropColumn('concept');
        });
    }
};
