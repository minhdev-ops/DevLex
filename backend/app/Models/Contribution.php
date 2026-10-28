<?php

namespace App\Models;

use App\Services\Glossary\TermText;
use Illuminate\Database\Eloquent\Model;

class Contribution extends Model
{
    public const STATUS_PENDING = 'pending';

    public const STATUS_APPROVED = 'approved';

    public const STATUS_REJECTED = 'rejected';

    public const STATUSES = [self::STATUS_PENDING, self::STATUS_APPROVED, self::STATUS_REJECTED];

    /** License mặc định cho đóng góp cộng đồng (cho phép tái sử dụng + thương mại). */
    public const CONTRIBUTOR_LICENSE = 'CC BY 4.0';

    protected $fillable = [
        'id', 'user_id', 'contributor_name',
        'tier_1_acronym', 'tier_1_full_name_en', 'tier_1_short_definition',
        'tier_2_detailed_explanation', 'status', 'review_note', 'reviewed_by', 'term_id',
    ];

    protected $keyType = 'string';

    public $incrementing = false;

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    /** Sinh id bền vững cho term được tạo từ đóng góp đã duyệt. */
    public function candidateTermId(): string
    {
        return 'ct_'.substr(preg_replace('/[^a-z0-9]+/', '_', strtolower($this->tier_1_acronym ?: $this->tier_1_full_name_en)), 0, 34);
    }

    /**
     * Chuyển đóng góp thành dòng `terms` (Tầng 1 + attribution ghi công contributor).
     * FR-COMM-03: tên người đóng góp xuất hiện trong source_attribution.
     *
     * @return array<string, mixed>
     */
    public function toTermRow(?string $termId = null): array
    {
        $termId ??= $this->candidateTermId();

        return [
            'id' => $termId,
            'tier_1_acronym' => $this->tier_1_acronym ?: mb_substr($this->tier_1_full_name_en, 0, 40),
            'tier_1_full_name_en' => $this->tier_1_full_name_en,
            'tier_1_full_name_vi' => '',
            'concept' => TermText::conceptKey($this->tier_1_full_name_en) ?: null,
            'tier_1_short_definition' => $this->tier_1_short_definition,
            'tier_2_detailed_explanation' => $this->tier_2_detailed_explanation,
            'tier_2_metaphor_analogy' => null,
            'tier_3_category_tags' => ['Community'],
            'tier_3_difficulty_level' => 'Beginner',
            'tier_3_prerequisites' => [],
            'tier_3_related_terms' => [],
            'roadmap_career' => null,
            'source_attribution' => [self::contributorAttribution($this->contributor_name)],
        ];
    }

    /** Mảng ghi công cho một đóng góp cộng đồng (FR-COMM-03). */
    public static function contributorAttribution(string $contributorName): array
    {
        return [
            'component' => 'tier_1',
            'source' => 'DevLex Community',
            'author' => $contributorName,
            'license' => self::CONTRIBUTOR_LICENSE,
            'modification_status' => 'Đóng góp cộng đồng, đã qua kiểm duyệt',
            'authority_tier' => 3,
            'confidence' => 60,
        ];
    }

    /**
     * Cộng dồn ghi công contributor vào một term đã tồn tại (khi đóng góp bổ sung/dịch).
     * Không trùng lặp theo (author + component).
     *
     * @param  array<int, array<string, mixed>>  $existing
     * @return array<int, array<string, mixed>>
     */
    public static function mergeAttribution(array $existing, string $contributorName): array
    {
        $new = self::contributorAttribution($contributorName);
        foreach ($existing as $a) {
            if (($a['author'] ?? null) === $new['author'] && ($a['component'] ?? null) === $new['component']) {
                return $existing;
            }
        }
        $existing[] = $new;

        return $existing;
    }
}
