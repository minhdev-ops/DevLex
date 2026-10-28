<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Console\Command;

/**
 * Đóng gói toàn bộ kho thuật ngữ đã thu thập (NIST/RFC/MDN/CNCF + curated) thành
 * asset seed cho app Flutter — chiến lược pre-packaged DB của SRS mục 5 / issue #3,
 * để cài đặt mới tra cứu được offline ngay lần mở đầu mà chưa cần delta sync.
 *
 * Định dạng khớp `Term.fromJson` và `GlossaryDatabase._seedFromAsset`.
 */
class ExportSeed extends Command
{
    protected $signature = 'glossary:export-seed
        {--path= : Đích ghi file JSON (mặc định asset seed của app)}
        {--dry-run : chỉ đếm và báo kích thước dự kiến, không ghi file}';

    protected $description = 'Xuất bảng terms + term_aliases ra asset seed của app (offline-first)';

    /** @var array<string, true> id đã biết, để lọc tham chiếu mồ côi */
    private array $knownIds = [];

    private int $droppedRefs = 0;

    public function handle(): int
    {
        $path = $this->option('path') ?: base_path('../frontend/assets/seed/terms.json');
        $counts = [
            'terms' => Term::query()->count(),
            'aliases' => TermAlias::query()->count(),
        ];
        $this->knownIds = [];
        $this->droppedRefs = 0;

        if ($this->option('dry-run')) {
            $this->info(sprintf(
                'DRY-RUN: %d mục từ, %d alias -> %s (~%s MB nội dung)',
                $counts['terms'],
                $counts['aliases'],
                $path,
                number_format($this->estimateBytes() / 1_048_576, 1)
            ));

            return self::SUCCESS;
        }

        if ($counts['terms'] === 0) {
            $this->error('Bảng terms rỗng — chạy glossary:import trước khi xuất.');

            return self::FAILURE;
        }

        $dir = dirname($path);
        if (! is_dir($dir) && ! mkdir($dir, 0775, true) && ! is_dir($dir)) {
            $this->error("Không tạo được thư mục {$dir}.");

            return self::FAILURE;
        }

        $tempPath = $path.'.tmp';
        $out = fopen($tempPath, 'wb');
        if ($out === false) {
            $this->error("Không mở được file {$tempPath} để ghi.");

            return self::FAILURE;
        }

        // Nguồn thô lưu slug của chính nó trong prerequisites/related_terms; mang
        // sang asset mà không lọc thì sơ đồ lộ trình vẽ liên kết tới mục từ không có
        // thật, nên chỉ giữ tham chiếu khớp id có trong kho.
        $this->knownIds = array_fill_keys(Term::query()->pluck('id')->all(), true);

        $written = 0;
        $aliases = 0;

        try {
            $this->writeHead($out, $counts);
            Term::query()->orderBy('id')->cursor()->each(function (Term $term) use ($out, &$written): void {
                $this->writeItem($out, $written++, $this->termRow($term));
            });

            $this->writeAliasesHead($out);
            TermAlias::query()->orderBy('term_id')->orderBy('alias')->cursor()->each(
                function (TermAlias $alias) use ($out, &$aliases): void {
                    $this->writeItem($out, $aliases++, [
                        'termId' => $alias->term_id,
                        'alias' => $alias->alias,
                        'namingRuleNote' => $alias->naming_rule_note,
                    ]);
                }
            );
            $this->writeTail($out);
        } finally {
            fclose($out);
        }

        if (! rename($tempPath, $path)) {
            @unlink($tempPath);
            $this->error("Không chuyển được file tạm về {$path}.");

            return self::FAILURE;
        }

        $this->info(sprintf(
            'Đã ghi %d mục từ + %d alias vào %s (%s MB)',
            $written,
            $aliases,
            $path,
            number_format(filesize($path) / 1_048_576, 1)
        ));
        if ($this->droppedRefs > 0) {
            $this->warn(sprintf(
                'đã bỏ %d tham chiếu mồ côi ở prerequisites/related_terms (slug nguồn chưa được ánh xạ sang id)',
                $this->droppedRefs
            ));
        }

        return self::SUCCESS;
    }

    /**
     * Một dòng terms đúng hình `Term.fromJson` (camelCase theo model Dart, không phải
     * schema API snake_case) — `attribution` giữ nguyên mảng JSON trong DB vì
     * `Attribution.fromJson` đọc được cả khóa snake_case.
     *
     * @param  array<string, mixed>  $row
     */
    private function termRow(Term $term): array
    {
        $definition = (string) $term->tier_1_short_definition;
        $explanation = $term->tier_2_detailed_explanation;

        // Nguồn dạng NIST ghi cùng một văn bản vào cả hai tầng; mang sang asset thì
        // màn chi tiết sẽ lặp lại một đoạn, nên chỉ giữ tầng 2 khi nó thêm nội dung.
        if ($explanation !== null && trim($explanation) === trim($definition)) {
            $explanation = null;
        }

        return [
            'id' => $term->id,
            'acronym' => (string) $term->tier_1_acronym,
            'fullNameEn' => (string) $term->tier_1_full_name_en,
            'fullNameVi' => (string) ($term->tier_1_full_name_vi ?? ''),
            'shortDefinition' => $definition,
            'detailedExplanation' => $explanation,
            'metaphorAnalogy' => $term->tier_2_metaphor_analogy,
            'diagramUrl' => $term->tier_2_diagram_url,
            'categoryTags' => $term->tier_3_category_tags ?? [],
            'difficulty' => $term->tier_3_difficulty_level ?? 'Beginner',
            'prerequisites' => $this->knownRefs($term->tier_3_prerequisites ?? []),
            'relatedTerms' => $this->knownRefs($term->tier_3_related_terms ?? []),
            'career' => $term->roadmap_career,
            'concept' => $term->concept,
            'attribution' => $term->source_attribution ?? [],
        ];
    }

    /**
     * Chỉ giữ tham chiếu trỏ tới mục từ thật có trong kho.
     *
     * @param  array<int, mixed>  $refs
     * @return string[]
     */
    private function knownRefs(array $refs): array
    {
        $kept = [];
        foreach ($refs as $ref) {
            $id = (string) $ref;
            if (isset($this->knownIds[$id])) {
                $kept[] = $id;
            } else {
                $this->droppedRefs++;
            }
        }

        return $kept;
    }

    /** @param resource $out */
    private function writeHead($out, array $counts): void
    {
        fwrite($out, "{\n");
        fwrite($out, '  "version": 2,'."\n");
        fwrite($out, '  "generated_at": '.$this->encode(date('c')).",\n");
        fwrite($out, '  "counts": '.$this->encode($counts).",\n");
        fwrite($out, '  "terms": [');
    }

    /** @param resource $out */
    private function writeAliasesHead($out): void
    {
        fwrite($out, "\n  ],\n  \"aliases\": [");
    }

    /** @param resource $out */
    private function writeTail($out): void
    {
        fwrite($out, "\n  ]\n}\n");
    }

    /**
     * @param  resource  $out
     * @param  array<string, mixed>  $row
     */
    private function writeItem($out, int $index, array $row): void
    {
        if ($index > 0) {
            fwrite($out, ",\n");
        }
        fwrite($out, '    '.$this->encode($row));
    }

    private function encode(mixed $value): string
    {
        return json_encode(
            $value,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR
        );
    }

    private function estimateBytes(): int
    {
        return (int) Term::query()
            ->selectRaw('sum(length(tier_1_short_definition)'
                .' + length(coalesce(tier_2_detailed_explanation, ""))'
                .' + length(coalesce(cast(source_attribution as char), ""))'
                .' + length(coalesce(tier_1_full_name_en, ""))'
                .' + length(coalesce(tier_3_category_tags, ""))'
                .' + length(coalesce(tier_3_prerequisites, ""))'
                .' + length(coalesce(tier_3_related_terms, ""))) as bytes')
            ->value('bytes');
    }
}
