<?php

use App\Http\Controllers\Api\V1\ContributionController;
use App\Http\Controllers\Api\V1\DecoderController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TermController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('terms/search', [TermController::class, 'search']);
    Route::get('terms/{id}', [TermController::class, 'show'])->where('id', '[A-Za-z0-9_\-]+');

    Route::post('decoder/extract', [DecoderController::class, 'extract']);
    Route::get('sync/delta', [SyncController::class, 'delta']);

    // FR-COMM: Cổng đóng góp cộng đồng
    Route::post('contributions', [ContributionController::class, 'store']);
    Route::get('contributions', [ContributionController::class, 'index']);
    Route::post('contributions/{id}/approve', [ContributionController::class, 'approve'])->where('id', '[A-Za-z0-9_\-]+');
    Route::post('contributions/{id}/reject', [ContributionController::class, 'reject'])->where('id', '[A-Za-z0-9_\-]+');
});
