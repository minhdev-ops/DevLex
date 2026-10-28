<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Console\Command;

/**
 * Kiểm tra chất lượng kho thuật ngữ (issue #8: ưu tiên dữ liệu uy tín).
 * Chỉ đọc, không sửa — dùng để báo cáo trung thực trong issue và chặn CI với --strict.
 */
class GlossaryStats extends Command
{
    protected $signature = 'glossary:stats {--strict : thoát mã lỗi nếu có dòng thiếu định nghĩa hoặc ghi công nguồn}';

    protected $description = 'Đếm theo nguồn: định nghĩa trống, thiếu attribution, chưa dịch tiếng Việt, khái niệm đa nguồn';

    public function handle(): int
    {
        $rows = Term::query()
            ->selectRaw(<<<'SQL'
                COALESCE(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(source_attribution, '$[0].source')), 'null'), '(không rõ nguồn)') AS src,
                COUNT(*) AS terms,
                SUM(tier_1_short_definition IS NULL OR tier_1_short_definition = '') AS empty_def,
                SUM(source_attribution IS NULL OR JSON_LENGTH(source_attribution) = 0) AS no_attr,
                SUM(tier_1_full_name_vi IS NULL OR tier_1_full_name_vi = '') AS untranslated,
                ROUND(AVG(CAST(JSON_UNQUOTE(JSON_EXTRACT(source_attribution, '$[0].confidence')) AS UNSIGNED)), 1) AS avg_conf
            SQL)
            ->groupBy('src')
            ->orderByDesc('terms')
            ->get();

        $this->table(
            ['Nguồn', 'Mục từ', 'Trống định nghĩa', 'Thiếu ghi công', 'Chưa dịch VI', 'TB tin cậy'],
            $rows->map(fn (Term $r) => [
                (string) $r->src,
                (int) $r->terms,
                (int) $r->empty_def,
                (int) $r->no_attr,
                (int) $r->untranslated,
                (float) $r->avg_conf,
            ])->all()
        );

        $shared = Term::query()
            ->selectRaw('concept, COUNT(*) AS n')
            ->whereNotNull('concept')
            ->groupBy('concept')
            ->having('n', '>', 1)
            ->get();

        $this->info(sprintf(
            'Tổng %d mục từ · %d alias · %d khái niệm có từ 2 nguồn trở lên (%d lượt trùng lặp giữa các nguồn)',
            Term::count(),
            TermAlias::count(),
            $shared->count(),
            max(0, (int) $shared->sum('n') - $shared->count())
        ));

        if (! $this->option('strict')) {
            return self::SUCCESS;
        }

        $bad = (int) $rows->sum('empty_def') + (int) $rows->sum('no_attr');
        if ($bad > 0) {
            $this->warn("Bất thường dữ liệu: {$bad} dòng cần sửa.");

            return self::FAILURE;
        }

        $this->info('OK: mọi dòng đều có định nghĩa và ghi công nguồn.');

        return self::SUCCESS;
    }
}
