<?php

use App\Http\Middleware\EnsureModeratorToken;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'moderator' => EnsureModeratorToken::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })
    // Issue #8: NIST/RFC là trang HTML/text nên không có webhook -> nạp lại định kỳ.
    // NIST ~10.400 slug, mỗi slug một request (~1 req/s) nên chạy tuần, không chạy
    // hằng ngày: một lần quét mất hàng giờ và không có gì mới mỗi đêm.
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('glossary:import --source=nist')->weeklyOn(3, '03:00')->withoutOverlapping();
        $schedule->command('glossary:import --source=rfc4949')->weeklyOn(1, '03:30')->withoutOverlapping();
    })->create();
