<?php

namespace App\Services\Glossary;

use App\Models\Term;

/**
 * Ngữ cảnh khái niệm + điểm tin cậy (SRS mục 4, issue #8 giai đoạn 2).
 * Đọc nhiều dòng nên chỉ dùng cho chi tiết một mục từ, không dùng khi render hàng loạt.
 */
class TermContext
{
    /**
     * @return array{context_group: array, trust: array}
     */
    public static function payload(Term $term): array
    {
        $siblings = $term->siblingContexts();
        $own = $term->source_attribution ?? [];

        $agreeing = array_values(array_unique(array_filter(array_merge(
            array_column($own, 'source'),
            $siblings->pluck('source_attribution.0.source')->filter()->all()
        ))));
        $baseConfidence = (int) ($own[0]['confidence'] ?? 50);

        return [
            'context_group' => [
                'concept' => $term->concept,
                'contexts' => $siblings->map(fn (Term $sibling) => [
                    'id' => $sibling->id,
                    'source' => $sibling->source_attribution[0]['source'] ?? null,
                    'authority_tier' => $sibling->source_attribution[0]['authority_tier'] ?? null,
                    'confidence' => $sibling->source_attribution[0]['confidence'] ?? null,
                    'short_definition' => $sibling->tier_1_short_definition,
                    'author_link' => $sibling->source_attribution[0]['author_link'] ?? null,
                ])->values(),
            ],
            'trust' => [
                'authority_tier' => $own[0]['authority_tier'] ?? null,
                'base_confidence' => $baseConfidence,
                // Số nguồn độc lập cùng định nghĩa khái niệm này (issue #8: dữ liệu uy tín).
                'agreeing_sources' => $agreeing,
                'corroborated_confidence' => SourceRegistry::corroborate($baseConfidence, count($agreeing)),
            ],
        ];
    }
}
