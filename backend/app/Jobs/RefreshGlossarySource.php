<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Artisan;

/**
 * Chạy lại bước nhập glossary cho một nguồn, được đẩy từ webhook GitHub
 * (issue #8) hoặc từ scheduler. Chạy nền vì một lần nhập MDN ~600 request.
 */
class RefreshGlossarySource implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 1;

    public int $timeout = 3600;

    public function __construct(public string $source) {}

    public function handle(): void
    {
        Artisan::call('glossary:import', ['--source' => $this->source]);
    }
}
