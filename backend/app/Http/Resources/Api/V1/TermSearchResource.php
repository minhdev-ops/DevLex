<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TermSearchResource extends JsonResource
{
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
            'tier_3' => [
                'category_tags' => $this->tier_3_category_tags,
                'difficulty_level' => $this->tier_3_difficulty_level,
            ],
            'similarity' => $this->when(isset($this->similarity), fn () => round($this->similarity, 3)),
            'matched_alias' => $this->when(isset($this->matched_alias), fn () => $this->matched_alias),
        ];
    }
}
