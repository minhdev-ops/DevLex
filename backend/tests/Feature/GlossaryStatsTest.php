<?php

namespace Tests\Feature;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Báo cáo chất lượng dữ liệu dùng để nói số thật trong issue #8/#1,
 * và --strict để không lẫn phát hành khi có dòng thiếu định nghĩa/ghi công.
 */
class GlossaryStatsTest extends TestCase
{
    use RefreshDatabase;

    private function makeTerm(string $id, string $source, int $confidence, string $definition = 'Một định nghĩa.', string $vi = ''): Term
    {
        return Term::query()->create([
            'id' => $id,
            'tier_1_acronym' => strtoupper(substr($id, -3)),
            'tier_1_full_name_en' => str_replace('_', ' ', $id),
            'tier_1_full_name_vi' => $vi,
            'tier_1_short_definition' => $definition,
            'tier_3_category_tags' => [],
            'tier_3_difficulty_level' => 'Beginner',
            'tier_3_prerequisites' => [],
            'tier_3_related_terms' => [],
            'source_attribution' => [[
                'component' => 'tier_1',
                'source' => $source,
                'authority_tier' => 1,
                'confidence' => $confidence,
            ]],
        ]);
    }

    public function test_reports_counts_per_source(): void
    {
        $this->makeTerm('mdn_api', 'MDN Web Docs', 88, vi: 'giao diện lập trình ứng dụng');
        $this->makeTerm('nist_api', 'NIST CSRC Glossary', 95);
        TermAlias::query()->create(['term_id' => 'mdn_api', 'alias' => 'api']);

        $this->artisan('glossary:stats')
            ->expectsOutputToContain('MDN Web Docs')
            ->expectsOutputToContain('NIST CSRC Glossary')
            ->expectsOutputToContain('Tổng 2 mục từ · 1 alias')
            ->assertSuccessful();
    }

    public function test_counts_concepts_shared_by_several_sources(): void
    {
        $first = $this->makeTerm('rfc_acl', 'IETF RFC 4949', 93);
        $second = $this->makeTerm('mdn_acl', 'MDN Web Docs', 88);
        Term::query()->whereKey([$first->id, $second->id])->update(['concept' => 'accesscontrollist']);

        $this->makeTerm('nist_zta', 'NIST CSRC Glossary', 95);
        Term::query()->where('id', 'nist_zta')->update(['concept' => 'zerotrustarchitecture']);

        $this->artisan('glossary:stats')
            ->expectsOutputToContain('1 khái niệm có từ 2 nguồn trở lên (1 lượt trùng lặp giữa các nguồn)')
            ->assertSuccessful();
    }

    public function test_strict_fails_when_a_definition_is_empty(): void
    {
        $this->makeTerm('mdn_api', 'MDN Web Docs', 88);
        $this->makeTerm('rfc_ghost', 'IETF RFC 4949', 93, definition: '');

        $this->artisan('glossary:stats --strict')->assertFailed();
    }

    public function test_strict_passes_on_clean_data(): void
    {
        $this->makeTerm('mdn_api', 'MDN Web Docs', 88);
        $this->makeTerm('nist_api', 'NIST CSRC Glossary', 95);

        $this->artisan('glossary:stats --strict')
            ->expectsOutputToContain('OK: mọi dòng đều có định nghĩa')
            ->assertSuccessful();
    }
}
