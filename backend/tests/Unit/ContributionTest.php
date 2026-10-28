<?php

namespace Tests\Unit;

use App\Models\Contribution;
use PHPUnit\Framework\TestCase;

class ContributionTest extends TestCase
{
    private function contribution(array $attrs): Contribution
    {
        $c = new Contribution;
        $c->forceFill([
            'contributor_name' => 'Trần Minh',
            'tier_1_acronym' => 'gRPC',
            'tier_1_full_name_en' => 'gRPC Remote Procedure Call',
            'tier_1_short_definition' => 'Framework RPC mã nguồn mở.',
            ...$attrs,
        ]);

        return $c;
    }

    public function test_candidate_term_id_is_stable_and_prefixed(): void
    {
        $this->assertSame('ct_grpc', $this->contribution([])->candidateTermId());
    }

    public function test_to_term_row_credits_contributor_in_attribution(): void
    {
        $row = $this->contribution([])->toTermRow();

        $this->assertSame('ct_grpc', $row['id']);
        $this->assertSame('gRPC', $row['tier_1_acronym']);
        $this->assertEmpty($row['tier_1_full_name_vi']);   // chờ dịch
        $this->assertSame('Community', $row['tier_3_category_tags'][0]);
        $this->assertSame('Trần Minh', $row['source_attribution'][0]['author']);
        $this->assertSame(Contribution::CONTRIBUTOR_LICENSE, $row['source_attribution'][0]['license']);
    }

    public function test_merge_attribution_adds_once_without_duplicates(): void
    {
        $base = [
            ['component' => 'tier_1', 'source' => 'MDN Web Docs', 'author' => 'Mozilla Contributors'],
        ];

        $once = Contribution::mergeAttribution($base, 'Trần Minh');
        $this->assertCount(2, $once);

        $twice = Contribution::mergeAttribution($once, 'Trần Minh');
        $this->assertCount(2, $twice);   // không cộng trùng tác giả/component
    }

    public function test_status_constants(): void
    {
        $this->assertSame(['pending', 'approved', 'rejected'], Contribution::STATUSES);
    }
}
