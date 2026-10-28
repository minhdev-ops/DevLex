<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StoreContributionRequest;
use App\Models\Contribution;
use App\Services\Glossary\ContributionApproval;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ContributionController extends Controller
{
    /** FR-COMM-01: ghi nhận đề xuất vào hàng chờ kiểm duyệt. */
    public function store(StoreContributionRequest $request): JsonResponse
    {
        $contribution = Contribution::create([
            'id' => 'c_'.bin2hex(random_bytes(8)),
            'user_id' => $request->user()?->id,
            'status' => Contribution::STATUS_PENDING,
            ...$request->only([
                'contributor_name', 'tier_1_acronym', 'tier_1_full_name_en',
                'tier_1_short_definition', 'tier_2_detailed_explanation',
            ]),
        ]);

        return response()->json([
            'data' => $contribution,
            'message' => 'Đã ghi nhận đề xuất. Nội dung sẽ vào hàng chờ kiểm duyệt.',
        ], 201);
    }

    /** Danh sách: mặc định pending (cho moderator); lọc ?status=... */
    public function index(Request $request): JsonResponse
    {
        $status = $request->query('status', Contribution::STATUS_PENDING);
        $items = Contribution::query()
            ->when(in_array($status, Contribution::STATUSES, true), fn ($q) => $q->where('status', $status))
            ->latest()
            ->limit(100)
            ->get();

        return response()->json(['data' => $items]);
    }

    /**
     * FR-COMM-02/03: duyệt đóng góp -> tạo term mới (hoặc cộng dồn vào term trùng acronym),
     * ghi công contributor vào source_attribution.
     */
    public function approve(Request $request, string $id, ContributionApproval $approval): JsonResponse
    {
        $contribution = Contribution::findOrFail($id);
        $alreadyReviewed = $contribution->status === Contribution::STATUS_APPROVED;

        $term = $approval->approve($contribution, $request->user()?->id);

        if ($alreadyReviewed) {
            return response()->json(['message' => 'Đề xuất đã được duyệt trước đó.'], 200);
        }

        return response()->json(['data' => $contribution->refresh(), 'term_id' => $term->id]);
    }

    /** FR-COMM-02: từ chối kèm ghi chú. */
    public function reject(Request $request, string $id, ContributionApproval $approval): JsonResponse
    {
        $validated = $request->validate(['review_note' => ['required', 'string', 'max:2000']]);

        $contribution = Contribution::findOrFail($id);
        $approval->reject($contribution, $validated['review_note'], $request->user()?->id);

        return response()->json(['data' => $contribution]);
    }
}
