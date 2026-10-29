<?php

namespace App\Services\Glossary;

use Symfony\Component\Yaml\Yaml;

/**
 * Tiện ích tách front-matter YAML và làm sạch văn đề Markdown
 * (bỏ link, macro {{glossary()}}, ký tự đậm/nghiêng, heading).
 */
final class TermText
{
    /** @return array{0: array<string,mixed>, 1: string} [frontMatter, body] */
    public static function splitFrontMatter(string $doc): array
    {
        if (! preg_match('/^\s*---\r?\n(.*?)\r?\n---\r?\n(.*)$/s', $doc, $m)) {
            return [[], $doc];
        }

        try {
            $fm = Yaml::parse($m[1]) ?: [];
        } catch (\Throwable) {
            $fm = [];
        }

        return [is_array($fm) ? $fm : [], $m[2]];
    }

    /** Ép một giá trị front-matter YAML về chuỗi: mảng -> phần tử đầu, null -> ''. */
    public static function asText(mixed $value): string
    {
        if (is_array($value)) {
            $value = reset($value);
        }

        return is_scalar($value) ? trim((string) $value) : '';
    }

    /** Bỏ metadata, chỉ giữ chữ thường + ký tự cơ bản để tạo id bền vững. */
    public static function slugify(string $value, int $max = 30): string
    {
        $slug = strtolower(trim($value));
        $slug = preg_replace('/[^a-z0-9]+/', '-', $slug);
        $slug = trim($slug, '-');

        if ($slug === '') {
            $slug = 'term';
        }

        return mb_substr($slug, 0, $max);
    }

    /**
     * Id an toàn cho cột varchar($max): prefix + slug. Slug bị cụt thì thêm hậu tố
     * hash của toàn bộ slug để hai tên dài gần giống nhau không đè lên nhau
     * (NIST có tên dài hơn cả giới hạn id, ví dụ american-registry-for-internet-numbers).
     */
    public static function idFor(string $prefix, string $value, int $max = 64): string
    {
        $slug = self::slugify($value, PHP_INT_MAX);
        $budget = max(1, $max - strlen($prefix));

        if (strlen($slug) <= $budget) {
            return $prefix.$slug;
        }

        $hash = dechex(crc32($slug));

        return $prefix.substr($slug, 0, $budget - strlen($hash) - 1).'_'.$hash;
    }

    /**
     * Khóa khái niệm để nối các mục từ trùng tên giữa các nguồn (NIST/MDN/RFC/CNCF
     * cùng định nghĩa "access control list"). Chỉ dựa trên tên đầy đủ, KHÔNG dựa
     * viết tắt, vì viết tắt dễ đụng độ ("AC" = access control hay alternating current).
     * Trả về '' khi tên rỗng hoặc tên chỉ là ký hiệu (|x|, {X}, ⎾x⏋, "a"): sau khi
     * bỏ ký tự lạ chúng dồn lại thành một chữ cái và sẽ gộp nhầm mục không liên quan.
     */
    public static function conceptKey(string $fullName): string
    {
        $name = trim($fullName);
        if ($name === '' || preg_match('/^[\p{L}\p{N} .\'’"\/-]+$/u', $name) !== 1) {
            return '';
        }

        $key = mb_strtolower((string) preg_replace('/[^\p{L}\p{N}]+/u', '', $name));

        return mb_strlen($key) < 3 ? '' : mb_substr($key, 0, 64);
    }

    /**
     * Tên mở rộng của một mục từ chỉ có viết tắt: MDN/RFC ghi tên là "API" nhưng
     * định nghĩa mở đầu bằng "An API (Application Programming Interface)..." hoặc
     * "See: application programming interface." — lấy phần mở rộng đó làm khóa để
     * gộp với dòng đã ghi đủ tên ở nguồn khác. Trả '' khi không tìm thấy hoặc phần
     * mở rộng không cùng chữ cái đầu (tránh "API (American Petroleum Institute)"
     * bị gộp nhầm vào khái niệm giao diện lập trình).
     */
    public static function expansionKey(string $acronym, string $definition): string
    {
        $acronym = trim($acronym);
        if (preg_match('/^[\p{L}\p{N}\/.]{2,10}$/u', $acronym) !== 1) {
            return '';
        }

        $expanded = '';
        if (preg_match('/\b'.preg_quote($acronym, '/').'\s*\(([^()]{3,80})\)/iu', $definition, $m) === 1) {
            $expanded = $m[1];
        } elseif (preg_match('/^see:\s*(.+?)\.?\s*$/iu', trim($definition), $m) === 1) {
            $expanded = $m[1];
        }

        $expanded = trim($expanded);
        if ($expanded === '' || count(preg_split('/\s+/u', $expanded)) < 2) {
            return '';
        }

        $key = self::conceptKey($expanded);
        if ($key === '' || $key === self::conceptKey($acronym)) {
            return '';
        }

        $first = function (string $s): string {
            $plain = (string) preg_replace('/[^\p{L}\p{N}]+/u', '', mb_strtolower($s));

            return $plain === '' ? '' : mb_substr($plain, 0, 1);
        };

        return $first($expanded) === $first($acronym) ? $key : '';
    }

    /**
     * Làm sạch một đoạn Markdown thành văn bản thuần:
     * - {{glossary("X","Y")}} / {{Glossary("X")}} -> Y hoặc X
     * - [text](url) -> text
     * - **bold**, _italic_ -> bỏ marker
     * - heading "## ..." -> bỏ dòng
     */
    public static function clean(string $markdown): string
    {
        // {{glossary("X")}} / {{glossary("X","Y")}} -> giữ label hiển thị (Y), fallback X
        $text = preg_replace_callback(
            '/\{\{[Gg]lossary\(([^)]*)\)\}\}/u',
            function (array $m): string {
                preg_match_all('/"([^"]+)"/u', $m[1], $args);
                $vals = $args[1] ?? [];

                return $vals === [] ? '' : (string) end($vals);
            },
            $markdown
        );
        // giữ label của link markdown, bỏ url
        $text = preg_replace('/\[(.*?)\]\((.*?)\)/u', '$1', $text);
        $text = preg_replace('/^#{1,6}\s.*$/mu', '', $text);
        $text = preg_replace('/[*_`>#]+/', '', $text);
        // {{...}} còn sót (plant, kbd, ...) -> bỏ
        $text = preg_replace('/\{\{.*?\}\}/us', '', $text);
        $text = preg_replace('/[ \t]+/', ' ', $text);
        $text = preg_replace('/\s*\n\s*/', "\n", $text);

        return trim($text);
    }

    /** Trả về đoạn văn đầu tiên (definition cốt lõi, giới hạn độ dài). */
    public static function firstParagraph(string $body, int $maxWords = 60): string
    {
        $blocks = preg_split('/\n\s*\n/', trim($body), 2);
        $first = self::clean($blocks[0] ?? '');
        // gộp nhiều dòng liền nhau thành một dòng
        $first = preg_replace('/\s*\n\s*/', ' ', $first);

        if ($maxWords > 0) {
            $words = preg_split('/\s+/u', trim($first));
            if (count($words) > $maxWords) {
                $first = implode(' ', array_slice($words, 0, $maxWords)).'…';
            }
        }

        return trim($first);
    }

    /** Tách acronym dạng chữ in hoa: "Kubernetes" -> "", "API" -> "API", "… (REST)" -> "REST". */
    public static function extractAcronym(string $title): string
    {
        if (preg_match('/\(([A-Z][A-Za-z0-9\/]{1,9})\)/u', $title, $m)) {
            return $m[1];
        }
        // title toàn chữ hoa / viết tắt: API, AJAX, JWT
        $plain = trim($title);
        if (preg_match('/^[A-Z][A-Za-z0-9\/]{1,9}$/', $plain)) {
            return $plain;
        }

        return '';
    }

    /** title + mô tả ngắn, bỏ phần trong ngoặc đơn nếu có acronym. */
    public static function fullName(string $title): string
    {
        return trim(preg_replace('/\s*\([A-Z][A-Za-z0-9\/]{1,9}\)/u', '', $title));
    }
}
