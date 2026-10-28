<?php

namespace App\Services\Glossary;

/**
 * Parse 1 file glossary MDN: files/en-us/glossary/{slug}/index.md
 * (license CC BY-SA 2.5, tác giả Mozilla Contributors).
 */
class MdnParser
{
    public const LICENSE = 'CC BY-SA 2.5';

    public const AUTHOR = 'Mozilla Contributors';

    public function parse(string $slug, string $doc): ?ParsedTerm
    {
        [$fm, $body] = TermText::splitFrontMatter($doc);

        if (($fm['page-type'] ?? '') !== 'glossary-definition') {
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

        $related = $this->collectRelated($body);

        return new ParsedTerm(
            id: 'md_'.TermText::slugify($slug),
            source: 'mdn',
            acronym: TermText::extractAcronym($title) ?: $title,
            fullNameEn: TermText::fullName($title) ?: $title,
            shortDefinition: $short,
            detailedExplanation: $detailed,
            categoryTags: ['Web'],
            relatedSlugs: $related,
            difficulty: null,
            career: null,
            authorLink: 'https://developer.mozilla.org/en-US/docs/Glossary/'.$title,
            license: self::LICENSE,
            author: self::AUTHOR,
            modificationStatus: 'Chờ dịch sang tiếng Việt (Human-in-the-loop)',
        );
    }

    /** @return string[] slug liên quan từ các macro {{glossary("X", ...)}} */
    private function collectRelated(string $body): array
    {
        $out = [];
        if (preg_match_all('/\{\{[Gg]lossary\(\s*"([^"]+)"/u', $body, $m)) {
            foreach ($m[1] as $name) {
                $out[] = 'md_'.TermText::slugify($name);
            }
        }

        return array_values(array_unique($out));
    }
}
