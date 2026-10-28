<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Models\TermAlias;
use App\Services\Glossary\CncfParser;
use App\Services\Glossary\MdnParser;
use App\Services\Glossary\ParsedTerm;
use App\Services\Glossary\TermText;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

class ImportGlossary extends Command
{
    protected $signature = 'glossary:import
        {--source=all : mdn | cncf | nist | all}
        {--limit=0 : giới hạn số term mỗi nguồn (0 = toàn bộ)}
        {--dry-run : chỉ fetch+parse+xuất JSON ra storage, không ghi DB}';

    protected $description = 'Ingest thuật ngữ từ MDN Web Docs + CNCF Glossary vào Unified Schema';

    public function handle(): int
    {
        $source = strtolower($this->option('source') ?: 'all');
        $limit = (int) $this->option('limit');
        $dryRun = (bool) $this->option('dry-run');

        $sources = $source === 'all' ? ['mdn', 'cncf'] : [$source];
        $allRows = [];

        foreach ($sources as $src) {
            $parsed = match ($src) {
                'mdn' => $this->ingestMdn($limit),
                'cncf' => $this->ingestCncf($limit),
                default => [],
            };

            $this->info(sprintf('[%s] parsed %d thuật ngữ hợp lệ', $src, count($parsed)));

            if ($dryRun) {
                foreach ($parsed as $term) {
                    $allRows[] = $term->toTermRow();
                }

                continue;
            }

            $stored = $this->persist($parsed);
            $this->info(sprintf('[%s] đã upsert %d dòng vào bảng terms', $src, $stored));
        }

        if ($dryRun) {
            $path = storage_path('app/glossary_ingest.json');
            @mkdir(dirname($path), 0o775, true);
            file_put_contents($path, json_encode($allRows, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
            $this->info(sprintf('DRY-RUN: ghi %d thuật ngữ chuẩn hóa -> %s', count($allRows), $path));
        }

        return self::SUCCESS;
    }

    /** @return ParsedTerm[] */
    private function ingestMdn(int $limit): array
    {
        $files = $this->listGlossaryFiles('mdn/content', 'files/en-us/glossary/', 'index.md');
        $parser = new MdnParser;
        $out = [];

        foreach ($this->take($files, $limit) as [$slug, $rawUrl]) {
            $doc = Http::timeout(20)->get($rawUrl)->body();
            if ($term = $parser->parse($slug, $doc)) {
                $out[] = $term;
            }
        }

        return $out;
    }

    /** @return ParsedTerm[] */
    private function ingestCncf(int $limit): array
    {
        $files = $this->listGlossaryFiles('cncf/glossary', 'content/en/', '.md', ['_']);
        $parser = new CncfParser;
        $out = [];

        foreach ($this->take($files, $limit) as [$slug, $rawUrl]) {
            $doc = Http::timeout(20)->get($rawUrl)->body();
            if ($term = $parser->parse($slug, $doc)) {
                $out[] = $term;
            }
        }

        return $out;
    }

    /**
     * Dùng GitHub Trees API (recursive) để lấy danh sách file glossary, trả về [slug, rawUrl][].
     *
     * @param  string[]  $excludePrefixes  bỏ slug bắt đầu bằng các chuỗi này
     * @return array<int, array{0:string,1:string}>
     */
    private function listGlossaryFiles(string $repo, string $dir, string $suffix, array $excludePrefixes = []): array
    {
        $res = Http::withHeaders(['User-Agent' => 'DevLex-Glossary'])
            ->timeout(30)
            ->get("https://api.github.com/repos/{$repo}/git/trees/HEAD?recursive=1");

        if ($res->failed()) {
            $this->warn("Không đọc được cây thư mục {$repo}: HTTP {$res->status()}");

            return [];
        }

        $rawBase = "https://raw.githubusercontent.com/{$repo}/HEAD/";
        $out = [];

        foreach ($res->json('tree', []) as $node) {
            $path = $node['path'] ?? '';
            if (($node['type'] ?? '') !== 'blob' || ! str_starts_with($path, $dir) || ! str_ends_with($path, $suffix)) {
                continue;
            }

            $slug = $this->slugFromPath($path, $dir, $suffix);
            if ($slug === '' || (bool) array_filter($excludePrefixes, fn ($p) => str_starts_with($slug, $p))) {
                continue;
            }

            $out[] = [$slug, $rawBase.$path];
        }

        sort($out);

        return $out;
    }

    private function slugFromPath(string $path, string $dir, string $suffix): string
    {
        $rel = substr($path, strlen($dir));
        if ($suffix === 'index.md') {          // files/en-us/glossary/api/index.md -> api
            return basename(dirname($rel));
        }

        return basename($rel, $suffix);        // content/en/kubernetes.md -> kubernetes
    }

    /** @param  array<int, array{0:string,1:string}>  $files */
    private function take(array $files, int $limit): array
    {
        return $limit > 0 ? array_slice($files, 0, $limit) : $files;
    }

    /**
     * Upsert vào bảng terms + tạo alias cho acronym viết hoa ngắn.
     *
     * @param  ParsedTerm[]  $terms
     */
    private function persist(array $terms): int
    {
        $count = 0;
        foreach ($terms as $term) {
            $row = $term->toTermRow();
            Term::query()->updateOrCreate(['id' => $row['id']], $row);
            $count++;

            $acronym = $row['tier_1_acronym'];
            if ($acronym !== '' && mb_strlen($acronym) <= 6 && preg_match('/^[A-Z0-9\/]+$/', $acronym)) {
                TermAlias::query()->updateOrCreate(
                    ['alias' => strtolower($acronym)],
                    ['term_id' => $row['id'], 'naming_rule_note' => null],
                );
            }
        }

        return $count;
    }
}
