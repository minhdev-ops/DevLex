<?php

namespace App\Services\Glossary;

/**
 * Parse toàn bộ văn bản IETF RFC 4949 "Internet Security Glossary, Version 2".
 *
 * Định dạng RFC: mỗi mục từ bắt đầu bằng "   $ Term" (3 dấu cách + "$ "), phần
 * định nghĩa thụt đầu dòng >= 6 dấu cách. Xen kẽ là đầu/chân trang ("RFC 4949 …",
 * "Shirey … [Page N]"), ký tự form-feed, và dòng trắng tách đoạn. Nguồn này có
 * ~1657 mục từ bảo mật uy tín, giấy phép IETF (tái sử dụng kèm ghi công).
 */
class Rfc4949Parser
{
    private const TERM_RE = '/^ {3}\$ (.+)$/u';

    private const NOISE_RE = '/^(RFC 4949\b|Shirey\b|\x0C)/u';

    /**
     * @return ParsedTerm[]
     */
    public function parseDocument(string $text): array
    {
        $meta = SourceRegistry::get('rfc4949');
        $out = [];

        $term = null;
        $buf = [];

        foreach (preg_split('/\r\n|\r|\n/', $text) as $line) {
            if (preg_match(self::TERM_RE, $line, $m)) {
                if ($term !== null) {
                    $parsed = $this->build($term, $buf, $meta);
                    if ($parsed !== null) {
                        $out[] = $parsed;
                    }
                }
                $term = trim($m[1]);
                $buf = [];

                continue;
            }

            if ($term === null) {
                continue; // phần mở đầu RFC, chưa vào danh mục
            }

            if (preg_match(self::NOISE_RE, $line)) {
                continue; // đầu/chân trang, form-feed -> bỏ qua giữa mục từ
            }

            // Dòng nội dung phải thụt >= 6 dấu cách; dòng trắng giữ để tách đoạn.
            if (rtrim($line) === '' || preg_match('/^ {6}/', $line)) {
                $buf[] = $line;

                continue;
            }

            // Dòng thụt < 6 không phải nội dung -> mục từ kết thúc tại đây.
            $parsed = $this->build($term, $buf, $meta);
            if ($parsed !== null) {
                $out[] = $parsed;
            }
            $term = null;
            $buf = [];
        }

        if ($term !== null) {
            $parsed = $this->build($term, $buf, $meta);
            if ($parsed !== null) {
                $out[] = $parsed;
            }
        }

        return $this->resolveRelations($out);
    }

    /**
     * RFC tham chiếu chéo bằng "(See: ...)" -> biến chuỗi đó thành id thuật ngữ
     * thật trong cùng nguồn, để đồ thị quan hệ (FR-REL) có cạnh thay vì slug trôi nổi.
     *
     * @param  ParsedTerm[]  $terms
     * @return ParsedTerm[]
     */
    private function resolveRelations(array $terms): array
    {
        $index = [];
        foreach ($terms as $t) {
            $keys = [$t->fullNameEn, $t->acronym];
            if ($t->acronym !== $t->fullNameEn && preg_match('/^[A-Z0-9\/]{2,10}$/', $t->acronym) === 1) {
                $keys[] = $t->fullNameEn.' ('.$t->acronym.')';
            }
            foreach (array_filter($keys) as $key) {
                $index[TermText::slugify($key)][] = $t->id;
            }
        }

        foreach ($terms as $t) {
            $ids = [];
            foreach ($t->relatedSlugs as $slug) {
                foreach ($index[$slug] ?? [] as $id) {
                    if ($id !== $t->id) {
                        $ids[] = $id;
                    }
                }
            }
            $t->relatedSlugs = array_values(array_unique($ids));
        }

        return $terms;
    }

    /**
     * @param  array{label:string,license:string,author:string,tier:int,confidence:int}  $meta
     */
    private function build(string $term, array $buf, array $meta): ?ParsedTerm
    {
        $body = $this->assemble($buf);
        if ($body === '') {
            return null;
        }

        $acronym = TermText::extractAcronym($term);
        $fullName = TermText::fullName($term);
        if ($fullName === '') {
            $fullName = $term;
        }
        if ($acronym === '') {
            $acronym = $fullName;
        }

        return new ParsedTerm(
            id: $this->makeId($term),
            source: 'rfc4949',
            acronym: $acronym,
            fullNameEn: $fullName,
            shortDefinition: TermText::firstParagraph($body, 60),
            detailedExplanation: TermText::clean($body),
            categoryTags: ['Security', 'IETF'],
            relatedSlugs: $this->seeReferences($body),
            difficulty: 'Intermediate',
            career: null,
            authorLink: 'https://www.rfc-editor.org/rfc/rfc4949',
            license: $meta['license'],
            author: $meta['author'],
            modificationStatus: 'Trích nguyên văn RFC 4949 (IETF), chờ dịch tiếng Việt',
            authorityTier: $meta['tier'],
            confidence: $meta['confidence'],
        );
    }

    /**
     * Sinh id nội bộ an toàn cho cột varchar(40): prefix + slug(<=23) + crc32 hex(8)
     * để tránh va chạm khi nhiều mục từ bị cắt ngắn giống nhau.
     */
    private function makeId(string $term): string
    {
        $slug = TermText::slugify($term, 23);
        $hash = str_pad(dechex(crc32($term)), 8, '0', STR_PAD_LEFT);

        return 'rfc4949_'.$slug.'_'.$hash;
    }

    /** Gộp các dòng định nghĩa thành khối có tách đoạn, bỏ marker "(X)" đầu tiên. */
    private function assemble(array $buf): string
    {
        $paragraphs = [];
        $current = [];

        foreach ($buf as $line) {
            if (rtrim($line) === '') {
                if ($current !== []) {
                    $paragraphs[] = implode(' ', $current);
                    $current = [];
                }

                continue;
            }
            $t = trim($line);
            // Nối gạch nối mềm cuối dòng: "problem-" + "solving" -> "problem-solving"
            if ($current !== [] && str_ends_with($current[count($current) - 1], '-')) {
                $last = array_pop($current);
                $current[] = $last.$t;
            } else {
                $current[] = $t;
            }
        }
        if ($current !== []) {
            $paragraphs[] = implode(' ', $current);
        }

        $body = implode("\n\n", $paragraphs);
        // Đầu mục có các marker xếp chồng nhau,VD "1. (I) /certificate, CRL/ ...".
        // Bỏ lần lượt: số thứ tự nghĩa, marker từ loại (I/N/O/D), nhãn miền /../.
        for ($i = 0; $i < 4; $i++) {
            $before = $body;
            $body = ltrim((string) preg_replace('/^\s*\d+\.\s*/u', '', $body));
            $body = ltrim((string) preg_replace('/^\(([INOD])\)\s*/u', '', $body));
            $body = ltrim((string) preg_replace('/^\/[A-Za-z][A-Za-z0-9 .,\-]*?\/\s+/u', '', $body));
            if ($before === $body) {
                break;
            }
        }
        // Các cặp dấu chéo còn lại (đánh dấu cách dùng hiếm) -> bỏ dấu, giữ chữ.
        $body = preg_replace('/(?<=^|\s)\/([A-Za-z][A-Za-z0-9 .\-]*?)\/(?=\s|$)/u', '$1', $body);

        return trim((string) $body);
    }

    /**
     * Tách các chuỗi tham chiếu trong "(See: a, b.)" / "(See also: c.)" thành slug
     * để resolveRelations đổi sang id thật.
     *
     * @return string[]
     */
    private function seeReferences(string $body): array
    {
        if (! preg_match_all('/\(\s*See(?:\s+also)?\s*:?\s*([^()]*?)[.)]\s*\)/iu', $body, $m)) {
            return [];
        }

        $out = [];
        foreach ($m[1] as $chunk) {
            foreach (preg_split('/[,;\/]|(?:\balso\b)/u', $chunk) as $phrase) {
                $phrase = trim($phrase, " \t\n.,;:\"'()");
                if (mb_strlen($phrase) < 3 || str_word_count($phrase) > 6) {
                    continue;
                }
                $out[] = TermText::slugify($phrase);
            }
        }

        return array_values(array_unique(array_slice($out, 0, 10)));
    }
}
