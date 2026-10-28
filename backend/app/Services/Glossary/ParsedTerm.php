<?php

namespace App\Services\Glossary;

/**
 * Giá trị thuần một thuật ngữ đã chuẩn hóa từ nguồn (chưa chạm DB).
 * Tách khỏi Eloquent để parser có thể unit-test độc lập, không cần DB/mạng.
 */
class ParsedTerm
{
    public function __construct(
        public string $id,
        public string $source,          // mdn | cncf | nist
        public string $acronym,
        public string $fullNameEn,
        public string $shortDefinition,
        public ?string $detailedExplanation = null,
        public array $categoryTags = [],
        /** @var string[] slug/id nguồn đã quy đổi, dùng để suy quan hệ */
        public array $relatedSlugs = [],
        public ?string $difficulty = null,
        public ?string $career = null,
        public ?string $authorLink = null,
        public ?string $license = null,
        public ?string $author = null,
        public ?string $modificationStatus = null,
        public ?int $authorityTier = null,
        public ?int $confidence = null,
        /** @var string[] tài liệu chuẩn được trích làm nguồn (VD: "NIST SP 800-207") */
        public array $citedBy = [],
    ) {}

    /**
     * Chuyển sang dòng phù hợp cột của bảng `terms` (idempotent để upsert).
     * Độ uy tín nguồn (tier/confidence/cited_by) nhúng trong JSON source_attribution
     * nên không cần thêm cột DB.
     */
    public function toTermRow(): array
    {
        $attribution = [];
        if ($this->source !== null) {
            $attribution[] = array_filter([
                'component' => 'tier_1',
                'source' => self::sourceLabel($this->source),
                'author' => $this->author,
                'license' => $this->license,
                'author_link' => $this->authorLink,
                'modification_status' => $this->modificationStatus,
                'authority_tier' => $this->authorityTier,
                'confidence' => $this->confidence,
                'cited_by' => $this->citedBy ?: null,
            ], fn ($v) => $v !== null && $v !== '' && $v !== []);
        }

        return [
            'id' => $this->id,
            'tier_1_acronym' => $this->acronym ?: mb_substr($this->fullNameEn, 0, 40),
            'tier_1_full_name_en' => $this->fullNameEn,
            'tier_1_full_name_vi' => '',            // chờ dịch (Human-in-the-loop)
            'tier_1_short_definition' => $this->shortDefinition,
            'tier_2_detailed_explanation' => $this->detailedExplanation,
            'tier_2_metaphor_analogy' => null,       // chờ AI/biên soạn
            'tier_3_category_tags' => $this->categoryTags,
            'tier_3_difficulty_level' => $this->difficulty ?? 'Beginner',
            'tier_3_related_terms' => $this->relatedSlugs,
            'roadmap_career' => $this->career,
            'source_attribution' => $attribution,
        ];
    }

    public static function sourceLabel(string $source): string
    {
        return SourceRegistry::label($source);
    }
}
