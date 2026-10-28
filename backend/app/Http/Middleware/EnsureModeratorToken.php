<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * FR-COMM-02 (interim): bảo vệ các endpoint kiểm duyệt (approve/reject) bằng
 * một bearer token dành riêng cho moderator, cấu qua MODERATION_API_TOKEN.
 *
 * Đây là chốt kiểm soát nhẹ, không phụ thuộc gói xác thực bên ngoài. Nâng cấp
 * dự kiến: tài khoản Admin/Moderator + Sanctum (role-based) khi có luồng đăng nhập.
 */
class EnsureModeratorToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = (string) config('services.moderation.token', '');

        // Fail-closed: chưa cấu hình token thì từ chối mọi yêu cầu kiểm duyệt.
        if ($expected === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Kiểm duyệt chưa được bật (thiếu MODERATION_API_TOKEN).',
            ], Response::HTTP_SERVICE_UNAVAILABLE);
        }

        $provided = (string) $request->bearerToken();

        if ($provided === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Yêu cầu xác thực moderator (thiếu bearer token).',
            ], Response::HTTP_UNAUTHORIZED);
        }

        if (! hash_equals($expected, $provided)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Token kiểm duyệt không hợp lệ.',
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}
