<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TermDetailResource extends JsonResource
{
    /**
     * Delta sync render hàng nghìn dòng bằng resource này nên không được
     * phát sinh query thêm ở đây. Khối `context_group` / `trust` (đọc các mục từ
     * cùng khái niệm) chỉ tính cho chi tiết một mục từ — xem TermController::show.
     */
    public function toArray(Request $request): array
    {
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
            'roadmap_career' => $this->roadmap_career,
            // Khóa khái niệm: client offline tự gom các mục từ cùng khái niệm
            // để tính mức đồng thuận đa nguồn mà không cần thêm request nào.
            'concept' => $this->concept,
        ];
    }
}
