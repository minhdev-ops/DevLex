<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\TermDetailResource;
use App\Models\Term;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    /**
     * Delta Sync (SRS mục 5): trả bản ghi có updated_at > last_pulled_at.
     * Mobile dùng để cập nhật SQLite, giảm dung lượng truyền tải.
     */
    public function delta(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'last_pulled_at' => ['required', 'integer', 'min:0'],
        ]);

        $since = now()->setTimestamp((int) $validated['last_pulled_at']);

        $updated = Term::where('updated_at', '>', $since)
            ->orderBy('updated_at')
            ->get();

        return response()->json([
            'status' => 'success',
            'sync_timestamp' => now()->timestamp,
            'changes' => [
                'updated' => TermDetailResource::collection($updated)->resolve(),
                // Hard-delete chưa áp dụng ở MVP; hàng đợi cho Phase sau.
                'deleted_ids' => [],
            ],
        ]);
    }
}
