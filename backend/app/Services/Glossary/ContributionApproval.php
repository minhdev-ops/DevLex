<?php

namespace App\Services\Glossary;

use App\Models\Contribution;
use App\Models\Term;

/**
 * FR-COMM-02/03: đường duy nhất đưa nội dung đã kiểm duyệt vào kho thuật ngữ,
 * dùng chung cho API moderator và lệnh glossary:review để hai lối không lệch nhau.
 */
class ContributionApproval
{
    /** Cột hiệu đính -> cột trên bảng contributions. */
    private const EDITABLE = [
        'acronym' => 'tier_1_acronym',
        'name' => 'tier_1_full_name_en',
        'definition' => 'tier_1_short_definition',
        'explanation' => 'tier_2_detailed_explanation',
    ];

    /**
     * @param  array<string, string|null>  $edits  chuyên gia sửa nội dung rồi mới duyệt
     */
    public function approve(Contribution $contribution, ?int $reviewerId = null, array $edits = []): Term
    {
        if ($contribution->status === Contribution::STATUS_APPROVED) {
            return Term::query()->findOrFail($contribution->term_id);
        }

        $clean = $this->onlyEdits($edits);
        if ($clean !== []) {
            $contribution->update($clean);
            $contribution->refresh();
        }

        $existing = Term::query()
            ->whereRaw('LOWER(tier_1_acronym) = ?', [strtolower($contribution->tier_1_acronym)])
            ->first();

        if ($existing) {
            $existing->source_attribution = Contribution::mergeAttribution(
                $existing->source_attribution ?? [],
                $contribution->contributor_name,
            );
            $existing->save();
            $termId = $existing->id;
        } else {
            $termId = $contribution->candidateTermId();
            Term::query()->updateOrCreate(['id' => $termId], $contribution->toTermRow($termId));
        }

        $contribution->update([
            'status' => Contribution::STATUS_APPROVED,
            'term_id' => $termId,
            'reviewed_by' => $reviewerId,
        ]);

        return Term::query()->findOrFail($termId);
    }

    public function reject(Contribution $contribution, string $note, ?int $reviewerId = null): Contribution
    {
        $contribution->update([
            'status' => Contribution::STATUS_REJECTED,
            'review_note' => $note,
            'reviewed_by' => $reviewerId,
        ]);

        return $contribution;
    }

    /**
     * Bỏ qua tham số không truyền hoặc chuỗi rỗng để không ghi đè nội dung hợp lệ.
     *
     * @param  array<string, string|null>  $edits
     * @return array<string, string>
     */
    private function onlyEdits(array $edits): array
    {
        $out = [];
        foreach (self::EDITABLE as $key => $column) {
            $value = $edits[$key] ?? null;
            if ($value !== null && trim($value) !== '') {
                $out[$column] = trim($value);
            }
        }

        return $out;
    }
}
