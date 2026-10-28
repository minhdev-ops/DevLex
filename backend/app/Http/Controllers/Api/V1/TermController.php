<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\TermDetailResource;
use App\Http\Resources\Api\V1\TermSearchResource;
use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TermController extends Controller
{
    private const MAX_RESULTS = 20;

    public function search(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['required', 'string', 'max:100'],
            'fuzzy' => ['sometimes', 'boolean'],
        ]);

        $query = trim($validated['q']);
        $normalized = mb_strtolower(preg_replace('/[\s\-_.]+/', '', $query));
        $like = str_replace(['%', '_'], ['\%', '\_'], $normalized);
        $wantFuzzy = $request->boolean('fuzzy', true);

        $exactAlias = TermAlias::with('term')->whereRaw('LOWER(alias) = ?', [$normalized])->first();

        $candidates = Term::query()
            ->where(function ($sql) use ($like, $query) {
                // So khớp ở dạng đã bỏ khoảng trắng/gạch nối, vì "access control list"
                // và "access-control-list" phải tìm được cùng một mục từ.
                $sql->whereRaw($this->normalizeExpr('tier_1_acronym').' LIKE ?', ["%{$like}%"])
                    ->orWhereRaw($this->normalizeExpr('tier_1_full_name_en').' LIKE ?', ["%{$like}%"])
                    ->orWhereRaw('LOWER(tier_1_full_name_vi) LIKE ?', ['%'.str_replace(['%', '_'], ['\%', '\_'], mb_strtolower($query)).'%']);
            })
            ->get();

        if ($exactAlias && $exactAlias->term) {
            $candidates->prepend($exactAlias->term);
        }

        $results = $candidates
            ->map(function (Term $term) use ($normalized, $exactAlias) {
                $term->similarity = $this->similarity($normalized, $term);
                if ($exactAlias && $exactAlias->term_id === $term->id) {
                    $term->matched_alias = [
                        'alias' => $exactAlias->alias,
                        'naming_rule_note' => $exactAlias->naming_rule_note,
                    ];
                }

                return $term;
            })
            ->unique('id')
            ->sortByDesc('similarity')
            ->take(self::MAX_RESULTS)
            ->values();

        if ($wantFuzzy && $normalized !== '' && $results->count() < self::MAX_RESULTS) {
            $seen = $results->pluck('id')->all();
            $extra = Term::query()
                ->whereNotIn('id', $seen)
                ->where('tier_1_acronym', 'like', mb_substr($normalized, 0, 1).'%')
                ->get()
                ->map(function (Term $term) use ($normalized) {
                    $term->similarity = $this->similarity($normalized, $term);

                    return $term;
                })
                ->filter(fn ($t) => $t->similarity >= 0.6)
                ->sortByDesc('similarity')
                ->take(self::MAX_RESULTS - count($seen))
                ->values();

            $results = $results->concat($extra);
        }

        return response()->json([
            'status' => 'success',
            'data' => TermSearchResource::collection($results)->resolve(),
        ]);
    }

    public function show(string $id): TermDetailResource|JsonResponse
    {
        $term = Term::find($id);

        if (! $term) {
            return response()->json(['status' => 'error', 'message' => 'Term not found'], 404);
        }

        return new TermDetailResource($term);
    }

    /** Biểu thức SQL bỏ dấu cách/gạch nối/dấu chấm để so khớp tự do theo tên viết tắt. */
    private function normalizeExpr(string $column): string
    {
        return sprintf("LOWER(REPLACE(REPLACE(REPLACE(%s,'-',''),'.',''),' ',''))", $column);
    }

    private function similarity(string $needle, Term $term): float
    {
        $best = 0.0;
        foreach ([$term->tier_1_acronym, $term->tier_1_full_name_en] as $field) {
            $field = mb_strtolower(preg_replace('/[\s\-_.]+/', '', $field));
            if ($field === '') {
                continue;
            }
            if (str_starts_with($field, $needle) || str_contains($field, $needle)) {
                $best = max($best, 1.0);

                continue;
            }
            $dist = levenshtein($needle, $field);
            $score = 1 - $dist / max(mb_strlen($needle), mb_strlen($field), 1);
            $best = max($best, $score);
        }

        return $best;
    }
}
