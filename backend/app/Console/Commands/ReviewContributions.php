<?php

namespace App\Console\Commands;

use App\Models\Contribution;
use App\Services\Glossary\ContributionApproval;
use Illuminate\Console\Command;

/**
 * FR-COMM-02: bàn làm việc của kiểm duyệt viên. API /contributions/{id}/approve
 * cần token moderator, còn đường này cho người có quyền truy cập máy chủ --
 * cả hai cùng đi qua ContributionApproval nên kết quả không thể lệch nhau.
 */
class ReviewContributions extends Command
{
    protected $signature = 'glossary:review
        {id? : Mã đề xuất cần xem hoặc xử lý}
        {--approve : Duyệt đề xuất (kèm id), đưa vào kho thuật ngữ}
        {--reject : Từ chối đề xuất (kèm id và --note)}
        {--note= : Lý do từ chối, hiển thị lại cho người đóng góp}
        {--acronym= : Hiệu đính từ viết tắt trước khi duyệt}
        {--name= : Hiệu đính tên đầy đủ trước khi duyệt}
        {--definition= : Hiệu đính định nghĩa Tầng 1 trước khi duyệt}
        {--explain= : Hiệu đính giải thích Tầng 2 trước khi duyệt}
        {--reviewer= : id tài khoản đã xử lý đề xuất}
        {--limit=20 : Số đề xuất chờ liệt kê một lượt}';

    protected $description = 'Liệt kê hàng chờ kiểm duyệt, xem một đề xuất, duyệt/từ chối kèm hiệu đính';

    public function handle(ContributionApproval $approval): int
    {
        $approve = (bool) $this->option('approve');
        $reject = (bool) $this->option('reject');

        if ($approve && $reject) {
            $this->error('--approve và --reject loại trừ nhau.');

            return self::FAILURE;
        }

        if (! $approve && ! $reject) {
            return $this->argument('id') ? $this->show((string) $this->argument('id')) : $this->queue();
        }

        $id = (string) $this->argument('id');
        if ($id === '') {
            $this->error('Thiếu mã đề xuất: glossary:review <id> --approve');

            return self::FAILURE;
        }

        $contribution = Contribution::find($id);
        if (! $contribution) {
            $this->error("Không tìm thấy đề xuất {$id}.");

            return self::FAILURE;
        }

        return $reject
            ? $this->reject($approval, $contribution)
            : $this->accept($approval, $contribution);
    }

    private function queue(): int
    {
        $limit = max(1, (int) $this->option('limit'));
        $pending = Contribution::query()->pending()->latest()->limit($limit)->get();

        if ($pending->isEmpty()) {
            $this->info('Hàng chờ kiểm duyệt trống.');

            return self::SUCCESS;
        }

        $this->table(
            ['Mã', 'Viết tắt', 'Tên đầy đủ', 'Người đóng góp', 'Gửi lúc'],
            $pending->map(fn (Contribution $c) => [
                $c->id,
                (string) $c->tier_1_acronym,
                (string) $c->tier_1_full_name_en,
                (string) $c->contributor_name,
                $c->created_at?->toIso8601String() ?? '',
            ])->all()
        );

        $total = Contribution::query()->pending()->count();
        $this->info("{$total} đề xuất đang chờ; xem một đề xuất: glossary:review <mã>");

        return self::SUCCESS;
    }

    private function show(string $id): int
    {
        $contribution = Contribution::find($id);
        if (! $contribution) {
            $this->error("Không tìm thấy đề xuất {$id}.");

            return self::FAILURE;
        }

        foreach ([
            'Mã' => $contribution->id,
            'Trạng thái' => $contribution->status,
            'Viết tắt' => $contribution->tier_1_acronym,
            'Tên đầy đủ' => $contribution->tier_1_full_name_en,
            'Định nghĩa Tầng 1' => $contribution->tier_1_short_definition,
            'Giải thích Tầng 2' => $contribution->tier_2_detailed_explanation ?: '(không có)',
            'Người đóng góp' => $contribution->contributor_name,
            'Ghi chú kiểm duyệt' => $contribution->review_note ?: '(không có)',
        ] as $label => $value) {
            $this->line(sprintf('%-22s %s', $label.':', (string) $value));
        }

        return self::SUCCESS;
    }

    private function accept(ContributionApproval $approval, Contribution $contribution): int
    {
        $term = $approval->approve(
            $contribution,
            $this->option('reviewer') !== null ? (int) $this->option('reviewer') : null,
            [
                'acronym' => $this->option('acronym'),
                'name' => $this->option('name'),
                'definition' => $this->option('definition'),
                'explanation' => $this->option('explain'),
            ],
        );

        $contribution->refresh();
        $this->info("Đã duyệt {$contribution->id} → mục từ `{$term->id}`, ghi công {$contribution->contributor_name}.");

        return self::SUCCESS;
    }

    private function reject(ContributionApproval $approval, Contribution $contribution): int
    {
        $note = (string) $this->option('note');
        if (trim($note) === '') {
            $this->error('--reject bắt buộc --note để người đóng góp biết lý do.');

            return self::FAILURE;
        }

        $approval->reject(
            $contribution,
            $note,
            $this->option('reviewer') !== null ? (int) $this->option('reviewer') : null,
        );
        $this->warn("Đã từ chối {$contribution->id}.");

        return self::SUCCESS;
    }
}
