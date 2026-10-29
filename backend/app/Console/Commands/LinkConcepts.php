<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Services\Glossary\TermText;
use Illuminate\Console\Command;

/**
 * Nối các mục từ trùng khái niệm giữa nhiều nguồn bằng khóa `concept`
 * (SRS mục 4 / issue #8 giai đoạn 2). Giữ nguyên từng dòng để mỗi ngữ cảnh
 * (NIST = bảo mật, MDN = web, CNCF = đám mây) còn định nghĩa và giấy phép riêng;
 * API sẽ gộp chúng khi trả kết quả.
 */
class LinkConcepts extends Command
{
    protected $signature = 'glossary:link-concepts
        {--dry-run : chỉ thống kê, không ghi DB}';

    protected $description = 'Gán khóa concept cho bảng terms để gộp ngữ cảnh đa nguồn';

    private const CHUNK = 500;

    public function handle(): int
    {
        $groups = $this->buildGroups();

        if ($groups === []) {
            $this->warn('Không có mục từ nào có tên đầy đủ để gán concept.');

            return self::SUCCESS;
        }

        $shared = array_filter($groups, fn (array $ids) => count($ids) > 1);
        $this->info(sprintf(
            '%d khái niệm, trong đó %d khái niệm có nhiều mục từ (tổng %d dòng được ghép)',
            count($groups),
            count($shared),
            array_sum(array_map('count', $shared))
        ));

        foreach (array_slice($shared, 0, 10, true) as $key => $ids) {
            $this->line(sprintf('  %s x%d', $key, count($ids)));
        }

        if ($this->option('dry-run')) {
            $this->info('DRY-RUN: không ghi DB.');

            return self::SUCCESS;
        }

        $written = 0;
        foreach ($groups as $key => $ids) {
            foreach (array_chunk($ids, self::CHUNK) as $chunk) {
                $written += Term::query()->whereIn('id', $chunk)->update(['concept' => $key]);
            }
        }
        $this->info("đã gán concept cho {$written} dòng");

        return self::SUCCESS;
    }

    /** @return array<string, string[]> concept key => danh sách id term */
    private function buildGroups(): array
    {
        $groups = [];

        Term::query()
            ->select(['id', 'tier_1_acronym', 'tier_1_full_name_en', 'tier_1_short_definition'])
            ->cursor()
            ->each(function (Term $term) use (&$groups): void {
                $name = (string) $term->tier_1_full_name_en;
                $key = TermText::conceptKey($name);

                // Nguồn chỉ ghi tên bằng viết tắt ("API"): lấy tên mở rộng từ định
                // nghĩa để nối với dòng đã ghi đủ tên ở nguồn khác.
                if ($key !== '' && $key === TermText::conceptKey((string) $term->tier_1_acronym)) {
                    $expanded = TermText::expansionKey((string) $term->tier_1_acronym, (string) $term->tier_1_short_definition);
                    if ($expanded !== '') {
                        $key = $expanded;
                    }
                }

                if ($key === '') {
                    return;
                }

                $groups[$key][] = $term->id;
            });

        return $groups;
    }
}
