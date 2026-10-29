<?php

namespace App\Console\Commands;

use App\Models\Term;
use App\Models\TermAlias;
use App\Services\Glossary\CncfParser;
use App\Services\Glossary\MdnParser;
use App\Services\Glossary\NistParser;
use App\Services\Glossary\ParsedTerm;
use App\Services\Glossary\Rfc4949Parser;
use App\Services\Glossary\SourceRegistry;
use App\Services\Glossary\TermText;
use Illuminate\Console\Command;
use Illuminate\Database\QueryException;
use Illuminate\Http\Client\Pool;
use Illuminate\Support\Facades\Http;

class ImportGlossary extends Command
{
    protected $signature = 'glossary:import
        {--source=all : mdn | cncf | nist | rfc4949 | all}
        {--limit=0 : giới hạn số term mỗi nguồn (0 = toàn bộ)}
        {--pages=110 : số trang danh mục NIST để khám phá slug (110 trang ~ 10.400 slug)}
        {--chunk=500 : NIST: ghi DB sau mỗi N slug (0 = gộp hết rồi ghi một lần)}
        {--skip=0 : NIST: bỏ qua N slug đầu (hồi tiếp một đợt quệt bị dở dang)}
        {--dry-run : chỉ fetch+parse+xuất JSON ra storage, không ghi DB}';

    protected $description = 'Ingest thuật ngữ uy tín (NIST + MDN + CNCF + RFC 4949) vào Unified Schema kèm chấm điểm nguồn';

    public function handle(): int
    {
        $source = strtolower($this->option('source') ?: 'all');
        $limit = (int) $this->option('limit');
        $chunk = (int) $this->option('chunk');
        $dryRun = (bool) $this->option('dry-run');

        $sources = $source === 'all' ? ['nist', 'mdn', 'cncf', 'rfc4949'] : [$source];

        // NIST có ~10.400 slug, mỗi slug một request: phải ghi DB theo lô để
        // một lần chạy hỏng giữa chừng không xóa sạch hàng chục phút đã tải.
        if ($source === 'nist' && $chunk > 0 && ! $dryRun) {
            return $this->handleNistChunked($limit, $chunk);
        }

        $parsed = [];
        foreach ($sources as $src) {
            $batch = match ($src) {
                'mdn' => $this->ingestMdn($limit),
                'cncf' => $this->ingestCncf($limit),
                'nist' => $this->ingestNist($limit),
                'rfc4949' => $this->ingestRfc4949($limit),
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
     * @return array<int, array<string, mixed>> dòng đã sẵn sàng ghi DB/JSON
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
     * RFC 4949 là MỘT file văn bản thuần chứa ~1657 mục từ -> fetch một lần,
     * parse toàn bộ rồi cắt theo --limit.
     *
     * @return ParsedTerm[]
     */
    private function ingestRfc4949(int $limit): array
    {
        $res = Http::withHeaders(['User-Agent' => 'DevLex-Glossary'])
            ->timeout(60)
            ->get('https://www.rfc-editor.org/rfc/rfc4949.txt');

        if ($res->failed()) {
            $this->warn("Không tải được RFC 4949: HTTP {$res->status()}");

            return [];
        }

        $terms = (new Rfc4949Parser)->parseDocument($res->body());

        return $limit > 0 ? array_slice($terms, 0, $limit) : $terms;
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

        return $this->fetchNistTerms($this->discoverNistSlugs($pages, $limit), $ignored);
    }

    /**
     * Ghi DB theo lô cho NIST; mỗi lô tự nạp lại được nên chạy dở vẫn còn.
     */
    private function handleNistChunked(int $limit, int $chunk): int
    {
        $pages = max(1, (int) $this->option('pages'));
        $slugs = $this->discoverNistSlugs($pages, $limit);
        $total = count($slugs);

        $skip = max(0, (int) $this->option('skip'));
        if ($skip > 0) {
            $slugs = array_slice($slugs, $skip);
            $this->info("[nist] bỏ qua {$skip}/{$total} slug đầu (--skip)");
        }

        $this->info('[nist] '.count($slugs)." slug còn lại, ghi theo lô {$chunk}");

        $written = 0;
        $crossRefs = [];
        $remaining = count($slugs);
        foreach (array_chunk($slugs, $chunk) as $i => $part) {
            $rows = $this->corroborate($this->fetchNistTerms($part, $crossRefs));
            $written += $this->persist($rows);
            $this->info(sprintf(
                '[nist] lô %d: +%d dòng (đã xử lý %d/%d slug, tổng %d dòng)',
                $i + 1,
                count($rows),
                min($remaining, ($i + 1) * $chunk),
                $remaining,
                $written
            ));
        }

        $aliases = $this->persistNistAliases($crossRefs);
        $this->info("[nist] ghi {$aliases} alias từ trang tra chéo (stub)");

        return self::SUCCESS;
    }

    /**
     * Trang stub NIST ("3DES" -> triple_data_encryption_standard) không có định nghĩa
     * nhưng cho biết cách gọi nào thuộc khái niệm nào. Chỉ ghi alias khi mục đích
     * đã có trong DB (thứ tự quệt không đảm bảo đích được nạp trước).
     *
     * @param  array<int, array{alias:string, target:string}>  $crossRefs
     */
    private function persistNistAliases(array $crossRefs): int
    {
        if ($crossRefs === []) {
            return 0;
        }

        $existing = Term::query()->where('id', 'like', 'nist_%')->pluck('id')->flip();
        $count = 0;

        foreach ($crossRefs as $ref) {
            $alias = trim($ref['alias']);
            if ($alias === '' || mb_strlen($alias) > 100) {
                continue;
            }
            $targetId = TermText::idFor('nist_', $ref['target']);
            if (! $existing->has($targetId)) {
                continue;
            }

            TermAlias::query()->updateOrCreate(
                ['alias' => mb_strtolower($alias)],
                ['term_id' => $targetId, 'naming_rule_note' => 'NIST CSRC: trang tra chéo (stub)'],
            );
            $count++;
        }

        return $count;
    }

    /**
     * @param  string[]  $slugs
     * @param  array<int, array{alias:string, target:string}>  $crossRefs  gom liên kết chéo từ trang stub
     * @return ParsedTerm[]
     */
    private function fetchNistTerms(array $slugs, array &$crossRefs): array
    {
        $parser = new NistParser;
        $out = [];

        // ~10.400 slug, mỗi slug một trang HTML: gửi song song (vẫn khiêm tốn,
        // 3 phiên đồng thời) để toàn bộ đợt quệt còn ~1 giờ thay vì ~4 giờ.
        $responses = Http::pool(fn (Pool $pool) => array_map(
            fn (string $slug) => $pool->withHeaders(['User-Agent' => 'DevLex-Glossary'])
                ->timeout(20)
                ->get($this->nistUrl($slug)),
            array_values($slugs)
        ), 3);

        foreach (array_values($slugs) as $index => $slug) {
            $response = $responses[$index] ?? null;
            $html = ($response !== null && $response->successful())
                ? $response->body()
                : $this->fetchNistPage($slug);

            if ($html === null) {
                continue;   // lần chạy sau (hoặc --skip) sẽ bù trang thiếu
            }

            if ($term = $parser->parse($slug, $html)) {
                $out[] = $term;

                continue;
            }

            foreach ($parser->crossReferences($slug, $html) as $ref) {
                $crossRefs[$ref['alias'].'|'.$ref['target']] = $ref;
            }
        }

        return $out;
    }

    private function nistUrl(string $slug): string
    {
        return 'https://csrc.nist.gov/glossary/term/'.$slug;
    }

    /** Bù đơn chiếc cho trang lỗi/hỏng trong lô; null nếu vẫn không lấy được. */
    private function fetchNistPage(string $slug): ?string
    {
        $response = Http::withHeaders(['User-Agent' => 'DevLex-Glossary'])
            ->timeout(20)
            ->retry(2, 400, throw: false)
            ->get($this->nistUrl($slug));

        return $response->successful() ? $response->body() : null;
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
                ->retry(2, 400, throw: false)
                ->get("https://csrc.nist.gov/glossary?export=all&page={$p}")
                ->body();

            $found = 0;
            if (preg_match_all('~<a href="/glossary/term/([A-Za-z0-9_\-]+)"~', $html, $m)) {
                foreach ($m[1] as $s) {
                    $slugs[$s] = true;
                    $found++;
                }
            }

            if ($found === 0) {
                break; // hết danh mục, không gọi thêm
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
        $failed = [];

        foreach ($rows as $row) {
            // Ghi luôn khóa khái niệm để không phải chờ glossary:link-concepts
            // chạy lại sau mỗi lần nạp (issue #8 giai đoạn 2).
            $row['concept'] = TermText::conceptKey($row['tier_1_full_name_en'] ?? '') ?: null;

            try {
                Term::query()->updateOrCreate(['id' => $row['id']], $row);
            } catch (QueryException $e) {
                // Một dòng ghi hỏng không được xóa sạch công cả đợt quệt hàng giờ
                // (đợt NIST từng chết vì id dài hơn cỡ cột varchar(40)).
                $failed[] = $row['id'];
                $this->warn("[persist] bỏ qua {$row['id']}: ".$e->getMessage());

                continue;
            }

            $count++;

            $acronym = $row['tier_1_acronym'];
            if ($acronym !== '' && mb_strlen($acronym) <= 6 && preg_match('/^[A-Z0-9\/]+$/', $acronym)) {
                TermAlias::query()->updateOrCreate(
                    ['alias' => strtolower($acronym)],
                    ['term_id' => $row['id'], 'naming_rule_note' => null],
                );
            }
        }

        if ($failed !== []) {
            $this->warn(sprintf('[persist] %d dòng lỗi: %s', count($failed), implode(', ', array_slice($failed, 0, 10))));
        }

        return $count;
    }
}
