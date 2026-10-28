<?php

namespace Tests\Feature;

use App\Models\Term;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Giai đoạn 2 issue #8: cùng khái niệm ở nhiều nguồn phải được nối bằng khóa
 * concept và API trả về đủ ngữ cảnh + điểm tin cậy tăng theo số nguồn.
 */
class ConceptLinkingTest extends TestCase
{
    use RefreshDatabase;

    private function makeTerm(string $id, string $name, string $source, string $label, int $confidence, string $definition): Term
    {
        return Term::query()->create([
            'id' => $id,
            'tier_1_acronym' => strtoupper(substr($name, 0, 4)),
            'tier_1_full_name_en' => $name,
            'tier_1_full_name_vi' => '',
            'tier_1_short_definition' => $definition,
            'tier_3_category_tags' => [$source],
            'tier_3_difficulty_level' => 'Beginner',
            'tier_3_prerequisites' => [],
            'tier_3_related_terms' => [],
            'source_attribution' => [[
                'component' => 'tier_1',
                'source' => $label,
                'authority_tier' => 1,
                'confidence' => $confidence,
                'author_link' => "https://example.test/{$source}",
            ]],
        ]);
    }

    private function link(): void
    {
        $this->artisan('glossary:link-concepts')->assertSuccessful();
    }

    public function test_command_gives_same_concept_to_terms_with_equal_name(): void
    {
        $this->makeTerm('mdn_acl', 'access control list', 'mdn', 'MDN Web Docs', 88, 'Rules telling a system who may touch an object.');
        $this->makeTerm('rfc_acl', 'Access Control List', 'rfc4949', 'IETF RFC 4949', 93, 'A mechanism that implements access control for a resource.');
        $this->makeTerm('nist_unrelated', 'zero trust architecture', 'nist', 'NIST CSRC Glossary', 95, 'No implicit trust based on identity or location.');

        $this->link();

        $this->assertSame('accesscontrollist', Term::find('mdn_acl')->concept);
        $this->assertSame(Term::find('mdn_acl')->concept, Term::find('rfc_acl')->concept);
        $this->assertNotSame(Term::find('mdn_acl')->concept, Term::find('nist_unrelated')->concept);
    }

    public function test_detail_returns_other_contexts_and_corroborated_confidence(): void
    {
        $this->makeTerm('mdn_acl', 'access control list', 'mdn', 'MDN Web Docs', 88, 'Rules telling a system who may touch an object.');
        $this->makeTerm('rfc_acl', 'access control list', 'rfc4949', 'IETF RFC 4949', 93, 'A mechanism that implements access control for a resource.');
        $this->link();

        $res = $this->getJson('/api/v1/terms/rfc_acl')->assertOk();

        $res->assertJsonPath('data.context_group.concept', 'accesscontrollist');
        $contexts = $res->json('data.context_group.contexts');
        $this->assertCount(1, $contexts);
        $this->assertSame('mdn_acl', $contexts[0]['id']);
        $this->assertSame('MDN Web Docs', $contexts[0]['source']);
        $this->assertStringContainsString('Rules telling a system', $contexts[0]['short_definition']);

        // 2 nguồn độc lập xác nhận => confidence = 93 + 4
        $res->assertJsonPath('data.trust.base_confidence', 93)
            ->assertJsonPath('data.trust.corroborated_confidence', 97)
            ->assertJsonCount(2, 'data.trust.agreeing_sources');
    }

    public function test_lone_term_keeps_single_source_trust(): void
    {
        $this->makeTerm('cn_slo', 'service level objective', 'cncf', 'CNCF Cloud Native Glossary', 80, 'A target value a system tries to achieve.');
        $this->link();

        $res = $this->getJson('/api/v1/terms/cn_slo')->assertOk();
        $res->assertJsonPath('data.context_group.contexts', [])
            ->assertJsonPath('data.trust.corroborated_confidence', 80)
            ->assertJsonCount(1, 'data.trust.agreeing_sources');
    }

    public function test_unnamed_term_gets_no_concept_and_no_contexts(): void
    {
        // Khái quát hóa: mục từ thiếu tên đầy đủ không được gom bừa với nhau.
        $this->makeTerm('x1', '', 'mdn', 'MDN Web Docs', 88, 'no name one');
        $this->makeTerm('x2', '', 'nist', 'NIST CSRC Glossary', 95, 'no name two');
        $this->link();

        $this->assertNull(Term::find('x1')->concept);
        $this->assertSame([], Term::find('x1')->siblingContexts()->all());

        $this->getJson('/api/v1/terms/x1')
            ->assertOk()
            ->assertJsonPath('data.context_group.contexts', [])
            ->assertJsonPath('data.trust.corroborated_confidence', 88);
    }

    public function test_dry_run_does_not_write(): void
    {
        $this->makeTerm('mdn_acl', 'access control list', 'mdn', 'MDN Web Docs', 88, 'Rules.');

        $this->artisan('glossary:link-concepts --dry-run')->assertSuccessful();

        $this->assertNull(Term::find('mdn_acl')->refresh()->concept);
    }
}
