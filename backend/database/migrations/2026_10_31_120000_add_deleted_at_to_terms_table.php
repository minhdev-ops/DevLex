<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Xóa mềm để Delta Sync báo được deleted_ids cho client.
 *
 * Trước đây term bị xóa cứng nên app offline không bao giờ biết mà dọn, dữ liệu
 * cũ tồn tại vĩnh viễn trên máy người dùng.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('terms', function (Blueprint $table) {
            $table->softDeletes();
            // Delta sync lọc theo deleted_at > last_pulled_at.
            $table->index('deleted_at');
        });
    }

    public function down(): void
    {
        Schema::table('terms', function (Blueprint $table) {
            $table->dropIndex(['deleted_at']);
            $table->dropSoftDeletes();
        });
    }
};
