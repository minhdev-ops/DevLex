<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\TermDetailResource;
use App\Models\Term;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SyncController extends Controller
{
    private const DEFAULT_PAGE_SIZE = 500;

    /**
     * Delta Sync (SRS mục 5): trả bản ghi có updated_at > last_pulled_at.
     * Mobile dùng để cập nhật SQLite, giảm dung lượng truyền tải.
     *
     * Trả theo lô (keyset pagination trên cặp updated_at + id) vì một lần import
     * có thể cập nhật hàng nghìn dòng cùng timestamp; nếu không giới hạn thì
     * response phình tới hàng chục MB và dễ quá timeout phía client.
     */
    public function delta(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'last_pulled_at' => ['required', 'integer', 'min:0'],
            'page_size' => ['sometimes', 'integer', 'min:1', 'max:1000'],
            'cursor' => ['sometimes', 'string', 'max:200'],
        ]);

        $pageSize = (int) ($validated['page_size'] ?? self::DEFAULT_PAGE_SIZE);
        $after = $this->decodeCursor($validated['cursor'] ?? null);

        $query = Term::query()->orderBy('updated_at')->orderBy('id');

        if ($after === null) {
            $since = now()->setTimestamp((int) $validated['last_pulled_at']);
            $query->where('updated_at', '>', $since);
        } else {
            $since = now()->setTimestamp($after['t']);
            $query->where(function ($sql) use ($since, $after) {
                $sql->where('updated_at', '>', $since)
                    ->orWhere(function ($q) use ($since, $after) {
                        $q->where('updated_at', '=', $since)->where('id', '>', $after['i']);
                    });
            });
        }

        $rows = $query->limit($pageSize + 1)->get();
        $hasMore = $rows->count() > $pageSize;
        $page = $hasMore ? $rows->take($pageSize) : $rows;
        $last = $page->last();

        return response()->json([
            'status' => 'success',
            'sync_timestamp' => now()->timestamp,
            'has_more' => $hasMore,
            'next_cursor' => $hasMore && $last !== null ? $this->encodeCursor($last) : null,
            'changes' => [
                'updated' => TermDetailResource::collection($page)->resolve(),
                // Hard-delete chưa áp dụng ở MVP; hàng đợi cho Phase sau.
                'deleted_ids' => [],
            ],
        ]);
    }

    /** @return array{t: int, i: string}|null */
    private function decodeCursor(?string $cursor): ?array
    {
        if ($cursor === null || $cursor === '') {
            return null;
        }

        $decoded = json_decode((string) base64_decode($cursor, true), true);
        if (! is_array($decoded) || ! isset($decoded['t'], $decoded['i'])) {
            return null;
        }

        return ['t' => (int) $decoded['t'], 'i' => (string) $decoded['i']];
    }

    private function encodeCursor(Term $term): string
    {
        return base64_encode(json_encode([
            't' => $term->updated_at !== null ? $term->updated_at->timestamp : 0,
            'i' => $term->id,
        ]));
    }
}
