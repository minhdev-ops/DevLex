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
    ->withSchedule(function (Schedule $schedule): void {
        $schedule->command('glossary:import --source=nist')->dailyAt('03:00')->withoutOverlapping();
        $schedule->command('glossary:import --source=rfc4949')->weeklyOn(1, '03:30')->withoutOverlapping();
    })->create();
