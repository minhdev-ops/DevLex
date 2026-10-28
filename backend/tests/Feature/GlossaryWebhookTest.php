<?php

namespace Tests\Feature;

use App\Jobs\RefreshGlossarySource;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class GlossaryWebhookTest extends TestCase
{
    use RefreshDatabase;

    private const SECRET = 'whsec_test_secret';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.github_webhook.secret' => self::SECRET]);
        Queue::fake();
    }

    /**
     * Giả lập y hệt cách GitHub giao request: body thô + chữ ký HMAC trên chính body đó.
     */
    private function deliver(string $event, array $payload, ?string $secret = self::SECRET, bool $withSignature = true)
    {
        $body = json_encode($payload, JSON_UNESCAPED_SLASHES);
        $server = ['CONTENT_TYPE' => 'application/json', 'HTTP_X_GITHUB_EVENT' => $event];

        if ($withSignature) {
            $server['HTTP_X_HUB_SIGNATURE_256'] = 'sha256='.hash_hmac('sha256', $body, (string) $secret);
        }

        return $this->call('POST', '/api/v1/webhooks/github', [], [], [], $server, $body);
    }

    private function push(string $repo): array
    {
        return ['repository' => ['full_name' => $repo, 'name' => 'x'], 'ref' => 'refs/heads/main'];
    }

    public function test_push_from_mdn_repo_queues_a_refresh_job(): void
    {
        $res = $this->deliver('push', $this->push('mdn/content'));

        $res->assertStatus(202)->assertJson(['queued' => true, 'source' => 'mdn']);
        Queue::assertPushed(RefreshGlossarySource::class, fn ($job) => $job->source === 'mdn');
    }

    public function test_push_from_cncf_repo_queues_cncf_refresh(): void
    {
        $this->deliver('push', $this->push('cncf/glossary'))
            ->assertStatus(202)->assertJson(['source' => 'cncf']);

        Queue::assertPushed(RefreshGlossarySource::class, fn ($job) => $job->source === 'cncf');
    }

    public function test_tampered_signature_is_rejected(): void
    {
        $this->deliver('push', $this->push('mdn/content'), 'wrong-secret')
            ->assertStatus(403);

        Queue::assertNothingPushed();
    }

    public function test_missing_signature_is_rejected(): void
    {
        $this->deliver('push', $this->push('mdn/content'), null, false)->assertStatus(403);

        Queue::assertNothingPushed();
    }

    public function test_unknown_repo_is_ignored_without_queuing(): void
    {
        $this->deliver('push', $this->push('somebody/unrelated'))
            ->assertOk()->assertJsonMissingPath('queued');

        Queue::assertNothingPushed();
    }

    public function test_job_runs_the_import_command_for_its_source(): void
    {
        Artisan::shouldReceive('call')
            ->once()
            ->with('glossary:import', ['--source' => 'cncf']);

        (new RefreshGlossarySource('cncf'))->handle();
    }

    public function test_ping_event_replies_after_signature_check(): void
    {
        $this->deliver('ping', ['zen' => 'Keep it simple'])->assertOk()->assertJsonPath('message', 'pong');

        Queue::assertNothingPushed();
    }

    public function test_endpoint_fails_closed_when_secret_is_not_configured(): void
    {
        config(['services.github_webhook.secret' => null]);

        $this->deliver('push', $this->push('mdn/content'), null, false)->assertStatus(503);

        Queue::assertNothingPushed();
    }

    public function test_rapid_pushes_are_deduplicated(): void
    {
        $first = $this->deliver('push', $this->push('mdn/content'))->assertStatus(202);
        $second = $this->deliver('push', $this->push('mdn/content'))->assertOk();

        $first->assertJson(['queued' => true]);
        $second->assertJson(['queued' => false]);
        Queue::assertPushed(RefreshGlossarySource::class, 1);
    }
}
