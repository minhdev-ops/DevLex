<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Term extends Model
{
    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = [
        'id',
        'tier_1_acronym', 'tier_1_full_name_en', 'tier_1_full_name_vi', 'tier_1_short_definition',
        'tier_2_detailed_explanation', 'tier_2_metaphor_analogy', 'tier_2_diagram_url',
        'tier_3_category_tags', 'tier_3_difficulty_level', 'tier_3_prerequisites', 'tier_3_related_terms',
        'roadmap_career', 'source_attribution', 'concept',
    ];

    protected $casts = [
        'tier_3_category_tags' => 'array',
        'tier_3_prerequisites' => 'array',
        'tier_3_related_terms' => 'array',
        'source_attribution' => 'array',
    ];

    public const CAREERS = ['frontend', 'backend', 'devops', 'project_comm'];

    public const DIFFICULTIES = ['Beginner', 'Intermediate', 'Advanced'];

    public function aliases(): HasMany
    {
        return $this->hasMany(TermAlias::class, 'term_id');
    }

    /**
     * Các mục từ cùng khái niệm nhưng khác ngữ cảnh/nguồn. Chỉ dùng được khi
     * `concept` đã được gán (chưa gán => null, không truy vấn để tránh khớp
     * toàn bộ những dòng có concept null).
     *
     * @return Collection<int, self>
     */
    public function siblingContexts(): Collection
    {
        if ($this->concept === null || $this->concept === '') {
            return new Collection;
        }

        return self::query()
            ->where('concept', $this->concept)
            ->whereKeyNot($this->getKey())
            ->orderBy('tier_1_full_name_en')
            ->get();
    }
}
