<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Models\TermAlias;
use App\Services\Glossary\CncfParser;
use App\Services\Glossary\MdnParser;
use App\Services\Glossary\NistParser;
use App\Services\Glossary\ParsedTerm;
use App\Services\Glossary\SourceRegistry;
use App\Services\Glossary\TermText;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

class ImportGlossary extends Command
{
    protected $signature = 'glossary:import
        {--source=all : mdn | cncf | nist | all}
        {--limit=0 : giới hạn số term mỗi nguồn (0 = toàn bộ)}
        {--pages=3 : số trang danh mục NIST để khám phá slug}
        {--dry-run : chỉ fetch+parse+xuất JSON ra storage, không ghi DB}';

    protected $description = 'Ingest thuật ngữ uy tín (NIST + MDN + CNCF) vào Unified Schema kèm chấm điểm nguồn';

    public function handle(): int
    {
        $source = strtolower($this->option('source') ?: 'all');
        $limit = (int) $this->option('limit');
        $dryRun = (bool) $this->option('dry-run');

        $sources = $source === 'all' ? ['nist', 'mdn', 'cncf'] : [$source];

        $parsed = [];
        foreach ($sources as $src) {
            $batch = match ($src) {
                'mdn' => $this->ingestMdn($limit),
                'cncf' => $this->ingestCncf($limit),
                'nist' => $this->ingestNist($limit),
                default => [],
            };
            $this->info(sprintf('[%s] parsed %d thuật ngữ hợp lệ', $src, count($batch)));
            foreach ($batch as $term) {
                $parsed[] = $term;
            }
        }

        $rows = $this->corroborate($parsed);

        if ($dryRun) {
            $path = storage_path('app/glossary_ingest.json');
            @mkdir(dirname($path), 0o775, true);
            file_put_contents($path, json_encode($rows, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
            $this->info(sprintf('DRY-RUN: ghi %d thuật ngữ chuẩn hóa -> %s', count($rows), $path));

            return self::SUCCESS;
        }

        $stored = $this->persist($rows);
        $this->info(sprintf('đã upsert %d dòng vào bảng terms', $stored));

        return self::SUCCESS;
    }

    /**
     * Ghép đa nguồn theo acronym/tên đầy đủ: cùng khái niệm xuất hiện ở >=2 nguồn uy tín
     * thì tăng confidence (corroboration) và ghi danh sách nguồn xác nhận.
     *
     * @param  ParsedTerm[]  $terms
     * @return array<int, array<string, mixed>>  dòng đã sẵn sàng ghi DB/JSON
     */
    private function corroborate(array $terms): array
    {
        $rows = [];
        $index = [];   // key => position trong $rows
        foreach ($terms as $term) {
            $row = $term->toTermRow();
            $key = mb_strtolower($term->acronym !== '' ? $term->acronym : $term->fullNameEn);
            $srcLabel = SourceRegistry::label($term->source);

            if (isset($index[$key])) {
                $i = $index[$key];
                $sources = $rows[$i]['source_attribution'];
                // chỉ cộng dồn nếu nguồn khác biệt
                if (! in_array($srcLabel, array_column($sources, 'source'), true)) {
                    $sources[] = $row['source_attribution'][0];
                    $rows[$i]['source_attribution'] = $sources;
                    $base = (int) $rows[$i]['source_attribution'][0]['confidence'];
                    $rows[$i]['source_attribution'][0]['confidence'] =
                        SourceRegistry::corroborate($base, count($sources));
                }

                continue;
            }

            $index[$key] = count($rows);
            $rows[] = $row;
        }

        return $rows;
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

    /** @return ParsedTerm[] */
    private function ingestNist(int $limit): array
    {
        $pages = max(1, (int) $this->option('pages'));
        $slugs = $this->discoverNistSlugs($pages, $limit);
        $parser = new NistParser;
        $out = [];

        foreach ($slugs as $slug) {
            $html = Http::withHeaders(['User-Agent' => 'DevLex-Glossary'])
                ->timeout(20)
                ->get('https://csrc.nist.gov/glossary/term/'.$slug)
                ->body();

            if ($term = $parser->parse($slug, $html)) {
                $out[] = $term;
            }
        }

        return $out;
    }

    /**
     * Quệt các trang danh mục `?export=all&page=N` để lấy slug term chi tiết.
     *
     * @return string[]
     */
    private function discoverNistSlugs(int $pages, int $limit): array
    {
        $slugs = [];
        for ($p = 1; $p <= $pages; $p++) {
            $html = Http::withHeaders(['User-Agent' => 'DevLex-Glossary'])
                ->timeout(20)
                ->get("https://csrc.nist.gov/glossary?export=all&page={$p}")
                ->body();

            if (preg_match_all('~<a href="/glossary/term/([A-Za-z0-9_\-]+)"~', $html, $m)) {
                foreach ($m[1] as $s) {
                    $slugs[$s] = true;
                }
            }

            if ($limit > 0 && count($slugs) >= $limit) {
                break;
            }
        }

        $list = array_keys($slugs);

        return $limit > 0 ? array_slice($list, 0, $limit) : $list;
    }

    /**
     * Upsert các dòng đã chuẩn hóa vào bảng terms + tạo alias cho acronym viết hoa ngắn.
     *
     * @param  array<int, array<string, mixed>>  $rows
     */
    private function persist(array $rows): int
    {
        $count = 0;
        foreach ($rows as $row) {
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
