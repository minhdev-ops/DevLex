<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Mọi route trong /api đều là JSON API, nhưng Laravel chỉ trả 422 JSON khi
 * request có header "Accept: application/json". Nếu client quên header này
 * (curl, Postman, SDK tự viết) thì lỗi validation bị đổi thành redirect 302 về
 * trang chủ kèm HTML — client parse JSON sẽ vỡ.
 *
 * Middleware này ép Accept: application/json cho toàn bộ nhóm api để hình dạng
 * lỗi luôn nhất quán: {"message": "...", "errors": {...}}.
 */
class ForceJsonResponse
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
