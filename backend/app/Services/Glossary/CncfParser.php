<?php

namespace App\Services\Glossary;

/**
 * Parse 1 file glossary CNCF: content/en/{slug}.md
 * (license CC BY 4.0, tác giả Cloud Native Glossary Authors).
 * Chỉ nhận term có status = Completed.
 */
class CncfParser
{
    public const LICENSE = 'CC BY 4.0';

    public const AUTHOR = 'Cloud Native Glossary Authors';

    public function parse(string $slug, string $doc): ?ParsedTerm
    {
        [$fm, $body] = TermText::splitFrontMatter($doc);

        $status = trim((string) ($fm['status'] ?? ''));
        if ($status !== '' && strtolower($status) !== 'completed') {
            return null;
        }

        $title = trim((string) ($fm['title'] ?? ''));
        if ($title === '' || trim($body) === '') {
            return null;
        }

        $short = TermText::firstParagraph($body);
        if ($short === '') {
            return null;
        }

        $detailed = TermText::clean($body);

        $tags = is_array($fm['tags'] ?? null) ? array_values(array_filter($fm['tags'])) : [];
        $tags[] = 'cloud-native';

        $category = strtolower(trim((string) ($fm['category'] ?? '')));
        $difficulty = in_array('fundamental', $tags, true) ? 'Beginner' : 'Intermediate';
        $career = $category === 'technology' ? 'devops' : null;

        return new ParsedTerm(
            id: 'cn_'.TermText::slugify($slug),
            source: 'cncf',
            acronym: TermText::extractAcronym($title) ?: $title,
            fullNameEn: TermText::fullName($title) ?: $title,
            shortDefinition: $short,
            detailedExplanation: $detailed,
            categoryTags: $tags,
            relatedSlugs: $this->collectRelated($body),
            difficulty: $difficulty,
            career: $career,
            authorLink: 'https://github.com/cncf/glossary/blob/main/content/en/'.$slug.'.md',
            license: self::LICENSE,
            author: self::AUTHOR,
            modificationStatus: 'Chờ dịch sang tiếng Việt (Human-in-the-loop)',
        );
    }

    /** @return string[] id nội bộ từ các link chéo /slug/ trong thân bài */
    private function collectRelated(string $body): array
    {
        $out = [];
        if (preg_match_all('/\]\(\/([a-z0-9\-]+)\/?\)/i', $body, $m)) {
            foreach ($m[1] as $s) {
                if (! str_starts_with($s, 'http')) {
                    $out[] = 'cn_'.TermText::slugify($s);
                }
            }
        }

        return array_values(array_unique($out));
    }
}
