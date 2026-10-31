<?php

namespace App\Services\Glossary;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Support\Facades\Cache;

/**
 * Từ điển tra cứu cho FR-DEC-01 (giải mã JD).
 *
 * Trước đây mỗi request /decoder/extract nạp toàn bộ bảng terms + aliases vào
 * bộ nhớ; với kho ~10.000 dòng thì mỗi lần dán JD là một lần quét cả bảng.
 * Ở đây chỉ cache cặp khóa-đã-chuẩn-hóa => term_id (nhẹ), rồi lấy chi tiết
 * đúng những term khớp trong một query.
 */
final class TermDictionary
{
    private const CACHE_KEY = 'glossary:extract-dictionary:v1';

    /**
     * @return array<string, string> khóa đã bỏ khoảng trắng/gạch nối => term_id
     */
    public static function get(): array
    {
        return Cache::remember(self::CACHE_KEY, now()->addHour(), function (): array {
            $map = [];

            foreach (Term::query()->select('id', 'tier_1_acronym')->orderBy('id')->cursor() as $term) {
                $key = self::normalize((string) $term->tier_1_acronym);
                if ($key !== '') {
                    $map[$key] = (string) $term->id;
                }
            }

            // Alias ghi đè acronym: cách viết đầy đủ do người dùng quen dùng thắng.
            foreach (TermAlias::query()->select('alias', 'term_id')->cursor() as $alias) {
                $key = self::normalize((string) $alias->alias);
                if ($key !== '') {
                    $map[$key] = (string) $alias->term_id;
                }
            }

            return $map;
        });
    }

    /** Gọi sau khi dữ liệu thuật ngữ thay đổi (import, duyệt đóng góp, xóa). */
    public static function flush(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    public static function normalize(string $value): string
    {
        return mb_strtolower((string) preg_replace('/[\s\-_.,\/]+/', '', $value));
    }
}
