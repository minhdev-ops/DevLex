<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Jobs\RefreshGlossarySource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/**
 * Webhook GitHub cho kho nguồn glossary (issue #8 — tự động hóa thu thập).
 * MDN và CNCF giữ thuật ngữ trong repo GitHub, nên mỗi lần họ đổi file là
 * DevLex phải nạp lại; chữ ký HMAC SHA-256 chứng minh yêu cầu đến từ GitHub.
 */
class WebhookController extends Controller
{
    private const DEDUPE_MINUTES = 10;

    public function github(Request $request): JsonResponse
    {
        $secret = (string) config('services.github_webhook.secret');
        if ($secret === '') {
            // Fail-closed: chưa cấu hình secret thì từ chối, không im lặng bỏ qua.
            return response()->json([
                'status' => 'error',
                'message' => 'Webhook secret chưa được cấu hình',
            ], 503);
        }

        if (! $this->hasValidSignature($request, $secret)) {
            return response()->json(['status' => 'error', 'message' => 'Chữ ký không hợp lệ'], 403);
        }

        $event = $request->header('X-GitHub-Event', '');
        if ($event === 'ping') {
            return response()->json(['status' => 'success', 'message' => 'pong']);
        }

        if ($event !== 'push') {
            return response()->json(['status' => 'success', 'ignored' => 'only push events are handled']);
        }

        $repo = (string) $request->input('repository.full_name', '');
        $source = config('services.github_webhook.repos')[$repo] ?? null;

        if ($source === null) {
            return response()->json(['status' => 'success', 'ignored' => "repo không thuộc nguồn glossary: {$repo}"]);
        }

        // GitHub gửi dồn nhiều push liên tiếp; một lần nạp đã lấy hết thay đổi mới nhất.
        $lockKey = 'glossary:refresh:'.$source;
        if (Cache::has($lockKey)) {
            return response()->json(['status' => 'success', 'queued' => false, 'source' => $source]);
        }
        Cache::put($lockKey, now()->toIso8601String(), now()->addMinutes(self::DEDUPE_MINUTES));

        RefreshGlossarySource::dispatch($source);

        return response()->json(['status' => 'success', 'queued' => true, 'source' => $source], 202);
    }

    private function hasValidSignature(Request $request, string $secret): bool
    {
        $provided = (string) $request->header('X-Hub-Signature-256', '');
        if (! str_starts_with($provided, 'sha256=')) {
            return false;
        }

        $expected = 'sha256='.hash_hmac('sha256', $request->getContent(), $secret);

        return hash_equals($expected, $provided);
    }
}
