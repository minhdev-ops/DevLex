<?php

namespace Tests\Feature;

use App\Models\Contribution;
use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiEndpointTest extends TestCase
{
    use RefreshDatabase;

    private const MOD_TOKEN = 'test-moderator-token';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.moderation.token' => self::MOD_TOKEN]);
    }

    private function moderatorHeaders(): array
    {
        return ['Authorization' => 'Bearer '.self::MOD_TOKEN];
    }

    private function term(array $overrides = []): Term
    {
        return Term::query()->create(array_merge([
            'id' => 'mdn_api',
            'tier_1_acronym' => 'API',
            'tier_1_full_name_en' => 'Application Programming Interface',
            'tier_1_full_name_vi' => 'Giao diện lập trình ứng dụng',
            'tier_1_short_definition' => ' Cầu nối để chương trình giao tiếp với nhau.',
            'tier_2_detailed_explanation' => null,
            'tier_2_metaphor_analogy' => null,
            'tier_2_diagram_url' => null,
            'tier_3_category_tags' => ['Backend'],
            'tier_3_difficulty_level' => 'Beginner',
            'tier_3_prerequisites' => [],
            'tier_3_related_terms' => [],
            'roadmap_career' => 'backend',
            'source_attribution' => [
                ['component' => 'tier_1', 'source' => 'MDN Web Docs', 'license' => 'CC BY-SA 2.5',
                    'authority_tier' => 1, 'confidence' => 88],
            ],
        ], $overrides));
    }

    public function test_search_returns_matching_term(): void
    {
        $this->term();

        $res = $this->getJson('/api/v1/terms/search?q=API');
        $res->assertOk()->assertJsonPath('status', 'success');
        $ids = array_column($res->json('data'), 'id');
        $this->assertContains('mdn_api', $ids);
    }

    public function test_search_requires_query(): void
    {
        $this->getJson('/api/v1/terms/search')->assertStatus(422);
    }

    public function test_search_matches_multi_word_name_regardless_of_separators(): void
    {
        // Regression: "zero trust" từng trả về rỗng vì query được bỏ dấu cách
        // còn cột tên thì giữ nguyên dấu cách.
        $this->term([
            'id' => 'nist_zta',
            'tier_1_acronym' => 'ZTA',
            'tier_1_full_name_en' => 'zero trust architecture',
            'tier_1_full_name_vi' => 'kiến trúc zero trust',
        ]);

        foreach (['zero trust architecture', 'zero-trust-architecture', 'zero  trust architecture'] as $q) {
            $ids = array_column($this->getJson('/api/v1/terms/search?q='.urlencode($q))->json('data'), 'id');
            $this->assertContains('nist_zta', $ids, "truy vấn: {$q}");
        }
    }

    public function test_search_matching_an_alias_does_not_crash(): void
    {
        // Regression: query trùng alias từng gây 500 ("Property [alias] does not
        // exist on the Eloquent builder instance") khi gắn matched_alias.
        $term = $this->term(['id' => 'nist_2fa', 'tier_1_acronym' => 'Two-Factor Authentication']);
        TermAlias::create([
            'term_id' => $term->id,
            'alias' => '2FA',
            'naming_rule_note' => 'Viết tắt phổ biến',
        ]);

        $res = $this->getJson('/api/v1/terms/search?q=2FA');
        $res->assertOk();
        $ids = array_column($res->json('data'), 'id');
        $this->assertContains('nist_2fa', $ids);
    }

    public function test_search_finds_term_through_multi_word_alias(): void
    {
        // Alias NIST lưu dạng đẹp có dấu cách ("Triple Data Encryption Standard");
        // chính mục từ lại chỉ mang tên viết tắt TDEA -> chỉ alias mới khớp query.
        $term = $this->term([
            'id' => 'nist_triple-data-encryption-standard',
            'tier_1_acronym' => 'TDEA',
            'tier_1_full_name_en' => 'TDEA',
        ]);
        TermAlias::create([
            'term_id' => $term->id,
            'alias' => 'Triple Data Encryption Standard',
            'naming_rule_note' => 'NIST CSRC: trang trỏ chéo (stub)',
        ]);

        $res = $this->getJson('/api/v1/terms/search?q='.urlencode('triple data encryption standard'));
        $res->assertOk();
        $first = $res->json('data.0');
        $this->assertSame('nist_triple-data-encryption-standard', $first['id']);
        $this->assertSame('Triple Data Encryption Standard', $first['matched_alias']['alias']);
    }

    public function test_show_returns_three_tier_shape(): void
    {
        $this->term();

        $res = $this->getJson('/api/v1/terms/mdn_api');
        $res->assertOk();
        $this->assertSame('API', $res->json('data.tier_1.acronym'));
        $this->assertSame('CC BY-SA 2.5', $res->json('data.source_attribution.0.license'));
    }

    public function test_show_missing_term_is_404(): void
    {
        $this->getJson('/api/v1/terms/nope_xyz')->assertStatus(404);
    }

    public function test_delta_sync_returns_changes_since_cursor(): void
    {
        $term = $this->term();

        // Cursor = epoch 0 -> term phải xuất hiện.
        $res = $this->getJson('/api/v1/sync/delta?last_pulled_at=0');
        $res->assertOk()->assertJsonPath('status', 'success');
        $updated = $res->json('changes.updated');
        $this->assertContains('mdn_api', array_column($updated, 'id'));
        $this->assertArrayHasKey('tier_1', $updated[0]);

        // Cursor = tương lai -> không có gì mới.
        $future = $this->getJson('/api/v1/sync/delta?last_pulled_at='.(time() + 3600));
        $future->assertOk();
        $this->assertSame([], $future->json('changes.updated'));
        unset($term);
    }

    public function test_delta_sync_requires_cursor(): void
    {
        $this->getJson('/api/v1/sync/delta')->assertStatus(422);
    }

    public function test_delta_sync_pages_through_rows_with_identical_timestamp(): void
    {
        // Một lô import ghi hàng nghìn dòng cùng updated_at: pagination phải
        // đi tiếp được bằng cặp (updated_at, id), không lặp lại hay bỏ sót dòng.
        foreach (['t_a', 't_b', 't_c'] as $i => $id) {
            $this->term([
                'id' => $id,
                'tier_1_acronym' => 'AC'.$i,
                'tier_1_full_name_en' => 'batched term '.$i,
            ]);
        }
        $stamp = now()->subMinute();
        Term::query()->update(['updated_at' => $stamp]);

        $first = $this->getJson('/api/v1/sync/delta?last_pulled_at=0&page_size=2');
        $first->assertOk()->assertJsonPath('has_more', true);
        $this->assertCount(2, $first->json('changes.updated'));
        $cursor = $first->json('next_cursor');
        $this->assertNotNull($cursor);

        $second = $this->getJson('/api/v1/sync/delta?last_pulled_at=0&page_size=2&cursor='.$cursor);
        $second->assertOk()->assertJsonPath('has_more', false);
        $this->assertNull($second->json('next_cursor'));
        $this->assertSame(
            ['t_c'],
            array_column($second->json('changes.updated'), 'id'),
            'cursor phải trả đúng phần còn lại, không trùng trang đầu'
        );
    }

    public function test_delta_sync_ignores_a_garbage_cursor(): void
    {
        $this->term();

        $res = $this->getJson('/api/v1/sync/delta?last_pulled_at=0&cursor=not-base64-json');
        $res->assertOk();
        $this->assertContains('mdn_api', array_column($res->json('changes.updated'), 'id'));
    }

    public function test_delta_sync_page_size_is_capped(): void
    {
        $this->getJson('/api/v1/sync/delta?last_pulled_at=0&page_size=100000')->assertStatus(422);
    }

    public function test_detail_response_does_not_batch_query_siblings(): void
    {
        // Resource dùng cho delta sync không được phát sinh query per-row (N+1)
        // khi bảng có hàng chục nghìn dòng; context_group chỉ có ở chi tiết.
        $this->term(['id' => 'rfc_acl', 'tier_1_full_name_en' => 'access control list']);
        $this->term(['id' => 'mdn_acl', 'tier_1_full_name_en' => 'access control list']);

        $res = $this->getJson('/api/v1/sync/delta?last_pulled_at=0');
        $res->assertOk();
        foreach ($res->json('changes.updated') as $row) {
            $this->assertArrayNotHasKey('context_group', $row);
            $this->assertArrayNotHasKey('trust', $row);
        }

        $this->getJson('/api/v1/terms/rfc_acl')
            ->assertOk()
            ->assertJsonPath('data.context_group.concept', null);
    }

    public function test_contribution_store_then_approve_creates_term(): void
    {
        $payload = [
            'contributor_name' => 'Trần Minh',
            'tier_1_acronym' => 'gRPC',
            'tier_1_full_name_en' => 'gRPC Remote Procedure Call',
            'tier_1_short_definition' => 'Framework RPC mã nguồn mở.',
        ];

        $store = $this->postJson('/api/v1/contributions', $payload);
        $store->assertStatus(201);
        $id = $store->json('data.id');
        $this->assertSame(Contribution::STATUS_PENDING, $store->json('data.status'));

        $approve = $this->postJson("/api/v1/contributions/{$id}/approve", [], $this->moderatorHeaders());
        $approve->assertOk();
        $termId = $approve->json('term_id');

        $term = Term::find($termId);
        $this->assertNotNull($term);
        $this->assertSame('gRPC', $term->tier_1_acronym);
        // FR-COMM-03: contributor được ghi vào source_attribution.
        $authors = array_column($term->source_attribution, 'author');
        $this->assertContains('Trần Minh', $authors);
    }

    public function test_contribution_reject_records_note(): void
    {
        $store = $this->postJson('/api/v1/contributions', [
            'contributor_name' => 'Người Góp Ý',
            'tier_1_acronym' => 'XYZ',
            'tier_1_full_name_en' => 'Xyz Thing',
            'tier_1_short_definition' => 'Mô tả ngắn.',
        ]);
        $id = $store->json('data.id');

        $this->postJson("/api/v1/contributions/{$id}/reject", ['review_note' => 'Chưa đủ căn cứ.'], $this->moderatorHeaders())
            ->assertOk()
            ->assertJsonPath('data.status', Contribution::STATUS_REJECTED);

        $this->assertNull(Term::query()->whereRaw('LOWER(tier_1_acronym) = ?', ['xyz'])->first());
    }

    public function test_approve_requires_moderator_token(): void
    {
        $store = $this->postJson('/api/v1/contributions', [
            'contributor_name' => 'Ai Đó',
            'tier_1_acronym' => 'AUTHZ',
            'tier_1_full_name_en' => 'Authz Probe',
            'tier_1_short_definition' => 'Probe.',
        ]);
        $id = $store->json('data.id');

        // Không có token -> 401.
        $this->postJson("/api/v1/contributions/{$id}/approve")->assertStatus(401);
        // Sai token -> 403.
        $this->postJson("/api/v1/contributions/{$id}/approve", [], ['Authorization' => 'Bearer wrong'])
            ->assertStatus(403);
        // Endpoint chưa được duyệt vẫn pending, chưa tạo term.
        $this->assertNull(Term::query()->find('ct_authz'));
    }

    public function test_contribution_store_validates_required_fields(): void
    {
        $this->postJson('/api/v1/contributions', ['contributor_name' => 'A'])
            ->assertStatus(422);
    }
}
