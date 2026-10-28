<?php

namespace App\Services\Glossary;

/**
 * Parse một trang từ điển NIST CSRC: https://csrc.nist.gov/glossary/term/{slug}
 * NIST là nguồn Public Domain (US government) -> uy tín cao cho thuật ngữ bảo mật.
 *
 * Trang gồm khối <div class="glossary-definition"> chứa:
 *   Abbreviations / Acronyms / Synonyms: <a id="term-abbr-link-N">ZTA</a> ...
 *   Definitions: <định nghĩa>  Sources: ...
 */
class NistParser
{
    public function parse(string $slug, string $html): ?ParsedTerm
    {
        if (! preg_match('~<div class="glossary-definition">(.*?)<div class="col-lg-4~s', $html, $m)) {
            return null;
        }
        $seg = $m[1];
        $plain = $this->toText($seg);

        $title = $this->title($html);
        if ($title === '') {
            return null;
        }

        $definition = $this->firstDefinition($plain);
        if ($definition === '') {
            return null;
        }

        $abbrev = $this->abbreviations($seg);
        $sources = $this->citedPublications($plain);

        $meta = SourceRegistry::get('nist');

        return new ParsedTerm(
            id: 'nist_'.TermText::slugify($slug, 40),
            source: 'nist',
            acronym: ($abbrev[0] ?? '') ?: $title,
            fullNameEn: $title,
            shortDefinition: $this->limitWords($definition, 60),
            detailedExplanation: $this->limitWords($definition, 180),
            categoryTags: array_values(array_unique(['Security', ...$this->formatTags($seg)])),
            relatedSlugs: [],
            difficulty: 'Intermediate',
            career: null,
            authorLink: 'https://csrc.nist.gov/glossary/term/'.$slug,
            license: $meta['license'],
            author: $meta['author'],
            modificationStatus: 'Trích nguyên văn NIST CSRC (Public Domain), chờ dịch tiếng Việt',
            authorityTier: $meta['tier'],
            confidence: $meta['confidence'],
            citedBy: $sources,
        );
    }

    private function title(string $html): string
    {
        if (! preg_match('~<title>(.*?)</title>~s', $html, $t)) {
            return '';
        }

        return trim(preg_replace('~\s*-\s*Glossary\s*\|\s*CSRC\s*$~u', '', html_entity_decode($t[1])));
    }

    /** @return string[] chỉ lấy nhãn link acronym (id="term-abbr-link-N"), bỏ danh sách nguồn */
    private function abbreviations(string $seg): array
    {
        preg_match_all('~<a[^>]+id="term-abbr-link-\d+"[^>]*>(.*?)</a>~is', $seg, $m);

        return array_values(array_filter(array_map(
            fn ($s) => trim(preg_replace('~\s+~', ' ', html_entity_decode(strip_tags($s)))),
            $m[1] ?? []
        )));
    }

    /** Danh sách tài liệu NIST được trích làm nguồn (VD: "NIST SP 800-207"). */
    private function citedPublications(string $plain): array
    {
        preg_match_all('~\bNIST\s+(?:SP|IR|ITL|FIPS|AI)\s*[0-9A-Za-z.\-]+\b~iu', $plain, $m);
        $out = array_values(array_unique(array_map('trim', $m[0] ?? [])));

        return array_slice($out, 0, 12);
    }

    /** @return string[] tag định dạng (data-term-format) nếu có */
    private function formatTags(string $seg): array
    {
        if (preg_match('~data-term-format="([^"]*)"~', $seg, $m) && trim($m[1]) !== '') {
            return [trim($m[1])];
        }

        return [];
    }

    private function firstDefinition(string $plain): string
    {
        if (! preg_match('~Definitions:\s*(.*?)(?:Sources:|$)~us', $plain, $d)) {
            return '';
        }
        $def = preg_replace('~^(?:&nbsp;|\s|[-–—:])+~u', '', $d[1]);

        return trim(preg_replace('~\s+~u', ' ', $def));
    }

    private function toText(string $html): string
    {
        $html = preg_replace('~<script.*?</script>|<style.*?</style>~is', ' ', $html);
        $text = html_entity_decode(strip_tags($html), HTML_ENTITIES, 'UTF-8');

        return trim(preg_replace('~\s+~u', ' ', str_replace("\xC2\xA0", ' ', $text)));
    }

    private function limitWords(string $text, int $max): string
    {
        $words = preg_split('~\s+~u', trim($text));
        if (count($words) > $max) {
            return implode(' ', array_slice($words, 0, $max)).'…';
        }

        return trim($text);
    }
}
