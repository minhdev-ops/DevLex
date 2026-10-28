<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Term;
use App\Services\Glossary\SourceRegistry;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TermDetailResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $siblings = $this->resource->siblingContexts();
        $agreeing = array_values(array_unique(array_filter(array_merge(
            array_column($this->source_attribution ?? [], 'source'),
            $siblings->pluck('source_attribution.0.source')->filter()->all()
        ))));
        $baseConfidence = (int) ($this->source_attribution[0]['confidence'] ?? 50);

        return [
            'id' => $this->id,
            'tier_1' => [
                'acronym' => $this->tier_1_acronym,
                'full_name_en' => $this->tier_1_full_name_en,
                'full_name_vi' => $this->tier_1_full_name_vi,
                'short_definition' => $this->tier_1_short_definition,
            ],
            'tier_2' => [
                'detailed_explanation' => $this->tier_2_detailed_explanation,
                'metaphor_analogy' => $this->tier_2_metaphor_analogy,
                'diagram_url' => $this->tier_2_diagram_url,
            ],
            'tier_3' => [
                'category_tags' => $this->tier_3_category_tags,
                'difficulty_level' => $this->tier_3_difficulty_level,
                'prerequisites' => $this->tier_3_prerequisites ?? [],
                'related_terms' => $this->tier_3_related_terms ?? [],
            ],
            'source_attribution' => $this->source_attribution,
            // Cùng khái niệm nhưng mỗi nguồn một ngữ cảnh (SRS mục 4, issue #8 giai đoạn 2).
            'context_group' => [
                'concept' => $this->concept,
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
                'authority_tier' => $this->source_attribution[0]['authority_tier'] ?? null,
                'base_confidence' => $baseConfidence,
                // Số nguồn độc lập cùng định nghĩa khái niệm này (issue #8: dữ liệu uy tín).
                'agreeing_sources' => $agreeing,
                'corroborated_confidence' => SourceRegistry::corroborate($baseConfidence, count($agreeing)),
            ],
        ];
    }
}
