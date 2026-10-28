<?php

namespace Tests\Feature;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Asset seed là toàn bộ vốn liếng offline của app (issue #3) nên định dạng phải
 * khớp đúng `Term.fromJson` của Dart và không được chứa dangling alias — một file
 * sai hình khiến lần mở đầu tiên của người dùng fail âm thầm trong SQLite.
 */
class ExportSeedTest extends TestCase
{
    use RefreshDatabase;

    private string $path;

    protected function setUp(): void
    {
        parent::setUp();

        $this->path = sys_get_temp_dir().'/glossary_seed_'.uniqid().'.json';
    }

    protected function tearDown(): void
    {
        @unlink($this->path);
        @unlink($this->path.'.tmp');

        parent::tearDown();
    }

    private function makeTerm(
        string $id,
        string $definition,
        ?string $explanation = null,
        string $vi = '',
        array $prerequisites = [],
    ): Term {
        return Term::query()->create([
            'id' => $id,
            'tier_1_acronym' => 'ACR',
            'tier_1_full_name_en' => 'Application Programming Interface',
            'tier_1_full_name_vi' => $vi,
            'tier_1_short_definition' => $definition,
            'tier_2_detailed_explanation' => $explanation,
            'tier_3_category_tags' => ['Backend'],
            'tier_3_difficulty_level' => 'Intermediate',
            'tier_3_prerequisites' => $prerequisites,
            'tier_3_related_terms' => [],
            'roadmap_career' => 'backend',
            'concept' => 'applicationprogramminginterface',
            'source_attribution' => [[
                'component' => 'tier_1',
                'source' => 'MDN Web Docs',
                'author_link' => 'https://developer.mozilla.org',
                'authority_tier' => 1,
                'confidence' => 88,
            ]],
        ]);
    }

    public function test_exports_rows_in_the_shape_the_dart_model_reads(): void
    {
        $this->makeTerm('term_pre_1', 'Mục từ tiên quyết của lộ trình.');
        $this->makeTerm(
            'mdn_api',
            'Quy tắc để hai ứng dụng nói chuyện với nhau.',
            vi: 'Giao diện lập trình ứng dụng',
            prerequisites: ['term_pre_1'],
        );
        TermAlias::query()->create([
            'term_id' => 'mdn_api',
            'alias' => 'api',
            'naming_rule_note' => 'Viết tắt giữ nguyên.',
        ]);

        $this->artisan('glossary:export-seed', ['--path' => $this->path])
            ->doesntExpectOutputToContain('mồ côi')
            ->assertSuccessful();

        $data = json_decode((string) file_get_contents($this->path), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(2, $data['version']);
        $this->assertSame(['terms' => 2, 'aliases' => 1], $data['counts']);
        $this->assertSame([
            'id', 'acronym', 'fullNameEn', 'fullNameVi', 'shortDefinition', 'detailedExplanation',
            'metaphorAnalogy', 'diagramUrl', 'categoryTags', 'difficulty', 'prerequisites',
            'relatedTerms', 'career', 'concept', 'attribution',
        ], array_keys($data['terms'][0]));

        $term = collect($data['terms'])->firstWhere('id', 'mdn_api');
        $this->assertSame('Giao diện lập trình ứng dụng', $term['fullNameVi']);
        $this->assertSame(['Backend'], $term['categoryTags']);
        $this->assertSame(['term_pre_1'], $term['prerequisites']);
        $this->assertSame('applicationprogramminginterface', $term['concept']);
        // attribution để nguyên khóa snake_case trong DB: Attribution.fromJson đọc được cả hai.
        $this->assertSame(88, $term['attribution'][0]['confidence']);

        $this->assertSame(['termId' => 'mdn_api', 'alias' => 'api', 'namingRuleNote' => 'Viết tắt giữ nguyên.'],
            $data['aliases'][0]);
    }

    public function test_drops_tier_2_text_that_only_repeats_the_definition(): void
    {
        $definition = 'Tổ chức cấp chứng chỉ số.';
        $this->makeTerm('nist_la', $definition, explanation: '  '.$definition.' ');
        $this->makeTerm('nist_x', $definition, explanation: 'Giải thích thêm: gồm CA, RA và kho khóa.');

        $this->artisan('glossary:export-seed', ['--path' => $this->path])->assertSuccessful();

        $rows = collect(json_decode((string) file_get_contents($this->path), true)['terms'])
            ->keyBy('id');

        $this->assertNull($rows['nist_la']['detailedExplanation']);
        $this->assertSame('Giải thích thêm: gồm CA, RA và kho khóa.', $rows['nist_x']['detailedExplanation']);
    }

    public function test_drops_relationship_references_the_corpus_cannot_resolve(): void
    {
        $this->makeTerm('mdn_api', 'Định nghĩa.');
        $this->makeTerm('nist_real', 'Định nghĩa khác.');
        Term::query()->whereKey('mdn_api')->update([
            'tier_3_prerequisites' => ['nist_real', 'cn_kho-gia'],
            'tier_3_related_terms' => ['term_khong_ton_tai'],
        ]);

        $this->artisan('glossary:export-seed', ['--path' => $this->path])
            ->expectsOutputToContain('đã bỏ 2 tham chiếu mồ côi')
            ->assertSuccessful();

        $rows = collect(json_decode((string) file_get_contents($this->path), true)['terms'])->keyBy('id');

        $this->assertSame(['nist_real'], $rows['mdn_api']['prerequisites']);
        $this->assertSame([], $rows['mdn_api']['relatedTerms']);
    }

    public function test_dry_run_reports_without_touching_the_file(): void
    {
        $this->makeTerm('mdn_api', 'Định nghĩa.');

        $this->artisan('glossary:export-seed', ['--path' => $this->path, '--dry-run' => true])
            ->expectsOutputToContain('DRY-RUN')
            ->assertSuccessful();

        $this->assertFileDoesNotExist($this->path);
    }

    public function test_refuses_to_publish_an_empty_corpus(): void
    {
        $this->artisan('glossary:export-seed', ['--path' => $this->path])
            ->expectsOutputToContain('Bảng terms rỗng')
            ->assertFailed();

        $this->assertFileDoesNotExist($this->path);
    }
}
