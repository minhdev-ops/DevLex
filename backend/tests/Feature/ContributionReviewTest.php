<?php

namespace Tests\Feature;

use App\Models\Contribution;
use App\Models\Term;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * FR-COMM-02: kiểm duyệt viên cần xem và xử lý hàng chờ mà không phải gọi curl.
 * Lệnh glossary:review và API moderator phải cho ra cùng một kết quả.
 */
class ContributionReviewTest extends TestCase
{
    use RefreshDatabase;

    private function pending(array $overrides = []): Contribution
    {
        return Contribution::query()->create([
            'id' => 'c_'.bin2hex(random_bytes(6)),
            'contributor_name' => 'Trần Minh',
            'tier_1_acronym' => 'gRPC',
            'tier_1_full_name_en' => 'gRPC Remote Procedure Call',
            'tier_1_short_definition' => 'Framework RPC mã nguồn mở.',
            'tier_2_detailed_explanation' => null,
            'status' => Contribution::STATUS_PENDING,
            ...$overrides,
        ]);
    }

    public function test_lists_the_moderation_queue(): void
    {
        $first = $this->pending();
        $second = $this->pending(['tier_1_acronym' => 'CRUD', 'tier_1_full_name_en' => 'Create Read Update Delete']);
        $this->pending(['tier_1_acronym' => 'OLD', 'status' => Contribution::STATUS_APPROVED, 'term_id' => 'ct_old']);

        $this->artisan('glossary:review')
            ->expectsOutputToContain($first->id)
            ->expectsOutputToContain($second->id)
            ->expectsOutputToContain('2 đề xuất đang chờ')
            ->assertSuccessful();
    }

    public function test_shows_one_contribution_in_full(): void
    {
        $c = $this->pending();

        $this->artisan('glossary:review '.$c->id)
            ->expectsOutputToContain('gRPC Remote Procedure Call')
            ->expectsOutputToContain('Framework RPC mã nguồn mở.')
            ->expectsOutputToContain('Trần Minh')
            ->assertSuccessful();

        $this->assertSame(Contribution::STATUS_PENDING, $c->refresh()->status, 'chỉ xem thì không được đổi trạng thái');
        $this->assertDatabaseMissing('terms', ['id' => 'ct_grpc']);
    }

    public function test_approve_creates_term_and_credits_contributor(): void
    {
        $c = $this->pending();

        $this->artisan('glossary:review '.$c->id.' --approve --reviewer=7')->assertSuccessful();

        $term = Term::find('ct_grpc');
        $this->assertNotNull($term, 'duyệt phải tạo mục từ ct_grpc');
        $this->assertSame('Trần Minh', $term->source_attribution[0]['author']);

        $c->refresh();
        $this->assertSame(Contribution::STATUS_APPROVED, $c->status);
        $this->assertSame(7, $c->reviewed_by);
    }

    public function test_expert_edits_are_stored_before_the_term_is_created(): void
    {
        $c = $this->pending(['tier_1_short_definition' => 'Viết tắt thôi.']);

        $this->artisan('glossary:review '.$c->id
            .' --approve'
            .' --definition="Khuôn mẫu cho gọi thủ tục từ xa qua HTTP/2."'
            .' --name="gRPC Remote Procedure Call (corrected)"')->assertSuccessful();

        $term = Term::find('ct_grpc');
        $this->assertSame('Khuôn mẫu cho gọi thủ tục từ xa qua HTTP/2.', $term->tier_1_short_definition);
        $this->assertSame('gRPC Remote Procedure Call (corrected)', $term->tier_1_full_name_en);
        $this->assertSame('Khuôn mẫu cho gọi thủ tục từ xa qua HTTP/2.', $c->refresh()->tier_1_short_definition);
    }

    public function test_reject_requires_a_note(): void
    {
        $c = $this->pending();

        $this->artisan('glossary:review '.$c->id.' --reject')->assertFailed();
        $this->assertSame(Contribution::STATUS_PENDING, $c->refresh()->status);

        $this->artisan('glossary:review '.$c->id.' --reject --note="Trùng với mục từ đã có."')
            ->assertSuccessful();

        $c->refresh();
        $this->assertSame(Contribution::STATUS_REJECTED, $c->status);
        $this->assertSame('Trùng với mục từ đã có.', $c->review_note);
        $this->assertNull(Term::find('ct_grpc'), 'từ chối thì không được đưa vào kho');
    }

    public function test_unknown_or_conflicting_flags_fail_without_writing(): void
    {
        $c = $this->pending();

        $this->artisan('glossary:review c_khong_ton_tai --approve')->assertFailed();
        $this->artisan('glossary:review '.$c->id.' --approve --reject')->assertFailed();
        $this->artisan('glossary:review --approve')->assertFailed();

        $this->assertSame(Contribution::STATUS_PENDING, $c->refresh()->status);
        $this->assertDatabaseMissing('terms', ['id' => 'ct_grpc']);
    }

    public function test_command_and_api_agree_on_an_already_approved_contribution(): void
    {
        config(['services.moderation.token' => 'cli-test-token']);
        $c = $this->pending();

        $this->artisan('glossary:review '.$c->id.' --approve')->assertSuccessful();

        $this->postJson("/api/v1/contributions/{$c->id}/approve", [], ['Authorization' => 'Bearer cli-test-token'])
            ->assertOk()
            ->assertJson(['message' => 'Đề xuất đã được duyệt trước đó.']);

        $this->assertSame(1, Term::query()->where('id', 'ct_grpc')->count());
    }
}
