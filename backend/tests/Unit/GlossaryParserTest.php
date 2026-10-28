<?php

namespace Tests\Unit;

use App\Services\Glossary\CncfParser;
use App\Services\Glossary\MdnParser;
use App\Services\Glossary\NistParser;
use App\Services\Glossary\Rfc4949Parser;
use App\Services\Glossary\SourceRegistry;
use App\Services\Glossary\TermText;
use PHPUnit\Framework\TestCase;

class GlossaryParserTest extends TestCase
{
    public function test_mdn_parses_real_api_entry(): void
    {
        $doc = <<<'MD'
---
title: API
slug: Glossary/API
page-type: glossary-definition
sidebar: glossarysidebar
---

An **API** (Application Programming Interface) is a set of features and rules that exist inside a software program enabling interaction with it through software.

In Web development, an API is generally a set of code features (e.g., {{glossary("method","methods")}}, events, and {{Glossary("URL","URLs")}}) a developer can use.

## See also

- [Web API reference](/en-US/docs/Web/API)
MD;

        $term = (new MdnParser)->parse('api', $doc);
        $this->assertNotNull($term);
        $this->assertSame('md_api', $term->id);
        $this->assertSame('API', $term->acronym);
        $this->assertStringContainsString('set of features and rules', $term->shortDefinition);
        $this->assertLessThanOrEqual(61, count(explode(' ', $term->shortDefinition)));
        $this->assertSame('CC BY-SA 2.5', $term->license);
        $this->assertSame('Mozilla Contributors', $term->author);
        $this->assertContains('md_method', $term->relatedSlugs);
        $this->assertContains('md_url', $term->relatedSlugs);
        // macro & link đã bị gỡ
        $this->assertStringNotContainsString('{{', $term->shortDefinition);
    }

    public function test_mdn_skips_non_definition_page_type(): void
    {
        $doc = "---\ntitle: Foo\npage-type: guide\n---\nBody here.";
        $this->assertNull((new MdnParser)->parse('foo', $doc));
    }

    public function test_cncf_parses_kubernetes_with_crosslinks(): void
    {
        $doc = <<<'MD'
---
title: Kubernetes
status: Completed
category: technology
tags: ["infrastructure", "fundamental", ""]
---

Kubernetes, often abbreviated as K8s, is an open source container orchestrator. It automates the lifecycle of containerized applications, managing them across a [distributed system](/distributed-systems/).

Kubernetes schedules [containers](/container/) across [nodes](/nodes/) in a [cluster](/cluster/).

## Problem it addresses

Infrastructure automation matters as [cloud computing](/cloud-computing/) gains popularity.
MD;

        $term = (new CncfParser)->parse('kubernetes', $doc);
        $this->assertNotNull($term);
        $this->assertSame('cn_kubernetes', $term->id);
        $this->assertSame('Kubernetes', $term->acronym);
        $this->assertStringContainsString('open source container orchestrator', $term->shortDefinition);
        $this->assertSame('CC BY 4.0', $term->license);
        $this->assertSame('Beginner', $term->difficulty);   // có tag fundamental
        $this->assertSame('devops', $term->career);          // category: technology
        foreach (['cn_container', 'cn_nodes', 'cn_cluster', 'cn_cloud-computing'] as $rel) {
            $this->assertContains($rel, $term->relatedSlugs);
        }
        $this->assertStringNotContainsString('##', $term->detailedExplanation);
    }

    public function test_cncf_skips_incomplete_status(): void
    {
        $doc = "---\ntitle: Wip\nstatus: In Progress\ncategory: pattern\n---\nSome text.";
        $this->assertNull((new CncfParser)->parse('wip', $doc));
    }

    public function test_term_row_shape_matches_terms_table(): void
    {
        $row = (new CncfParser)->parse('kubernetes', <<<'MD'
---
title: Kubernetes
status: Completed
category: technology
tags: ["fundamental"]
---

Kubernetes is a container orchestrator.
MD
        )->toTermRow();

        foreach ([
            'id', 'tier_1_acronym', 'tier_1_full_name_en', 'tier_1_full_name_vi',
            'tier_1_short_definition', 'tier_2_detailed_explanation', 'tier_3_category_tags',
            'tier_3_difficulty_level', 'tier_3_related_terms', 'roadmap_career', 'source_attribution',
        ] as $key) {
            $this->assertArrayHasKey($key, $row);
        }
        $this->assertSame('tier_1', $row['source_attribution'][0]['component']);
        $this->assertSame('CNCF Cloud Native Glossary', $row['source_attribution'][0]['source']);
    }

    public function test_nist_parses_term_page_and_tags_authority(): void
    {
        $html = '<title>Zero Trust Architecture - Glossary | CSRC</title><main>'
            .'<div class="glossary-definition"><div>'
            .'<strong>Abbreviations / Acronyms / Synonyms:</strong><p class="indent-1">'
            .'<a href="/glossary/term/zta" id="term-abbr-link-0">ZTA</a>'
            .'<a href="/glossary/term/zero-trust" id="term-abbr-link-1">zero trust</a>'
            .'<p>NIST SP 800-207 NIST IR 8432</p></div>'
            .'<strong>Definitions:</strong> &nbsp;&nbsp; An enterprise’s cybersecurity plan that '
            .'utilizes zero trust concepts and encompasses component relationships, workflow planning, '
            .'and access policies. Sources: NIST SP 800-207</div></div>'
            .'<div class="col-lg-4">sidebar</div></main>';

        $term = (new NistParser)->parse('zero_trust_architecture', $html);
        $this->assertNotNull($term);
        $this->assertSame('nist_zero-trust-architecture', $term->id);
        $this->assertSame('Zero Trust Architecture', $term->fullNameEn);
        $this->assertSame('ZTA', $term->acronym);
        $this->assertStringContainsString('cybersecurity plan', $term->shortDefinition);
        $this->assertSame('Public Domain', $term->license);
        $this->assertSame(1, $term->authorityTier);
        $this->assertSame(95, $term->confidence);
        $this->assertContains('NIST SP 800-207', $term->citedBy);
        $this->assertContains('Security', $term->categoryTags);

        $row = $term->toTermRow();
        $this->assertSame(1, $row['source_attribution'][0]['authority_tier']);
    }

    public function test_nist_keeps_acronymish_title_and_picks_real_expansion(): void
    {
        // Regression: NIST cross-liệt kê synonym giữa các trang. Trước đây acronym
        // bị gán nhầm từ abbrev[0] (vd "2FA" nhận "abstraction").
        $seg = static function (string $title, string $abbrLinks, string $def) {
            return '<title>'.$title.' - Glossary | CSRC</title><main>'
                .'<div class="glossary-definition"><div>'
                .'<strong>Abbreviations / Acronyms / Synonyms:</strong><p class="indent-1">'.$abbrLinks.'</p>'
                .'<strong>Definitions:</strong> &nbsp;&nbsp; '.$def.' Sources: NIST SP 800-53</div></div>'
                .'<div class="col-lg-4">sidebar</div></main>';
        };

        $twoFa = (new NistParser)->parse('2fa', $seg(
            '2FA',
            '<a id="term-abbr-link-0" href="/glossary/term/abstraction">abstraction</a>'
            .'<a id="term-abbr-link-1" href="/glossary/term/tfa">Two-Factor Authentication</a>',
            'Authentication using two or more factors.'
        ));
        $this->assertSame('2FA', $twoFa->acronym);
        $this->assertSame('Two-Factor Authentication', $twoFa->fullNameEn);

        $abstraction = (new NistParser)->parse('abstraction', $seg(
            'abstraction',
            '<a id="term-abbr-link-0" href="/glossary/term/2fa">2FA</a>',
            'View of an object that hides irrelevant detail.'
        ));
        // Title là từ thường -> không nhận synonym "2FA" làm acronym.
        $this->assertSame('abstraction', $abstraction->acronym);
        $this->assertSame('abstraction', $abstraction->fullNameEn);
    }

    public function test_nist_skips_page_without_definition_block(): void
    {
        $this->assertNull((new NistParser)->parse('missing', '<title>x - Glossary | CSRC</title><main>nope</main>'));
    }

    public function test_rfc4949_parses_entries_across_page_breaks(): void
    {
        $text = "intro\n"
            ."\x0C\n"
            ."RFC 4949         Internet Security Glossary, Version 2       August 2007\n"
            ."   \$ algorithm\n"
            ."      (I) A finite set of step-by-step instructions for a problem-\n"
            ."      solving or computation procedure, especially one that can be\n"
            ."      implemented by a computer. (See: cryptographic algorithm.)\n"
            ."\n"
            ."Shirey                       Informational                     [Page 17]\n"
            ."   \$ access control list (ACL)\n"
            ."      1. (N) /network/ A list of permissions attached to an object.\n"
            ."\n"
            ."      Tutorial: An ACL specifies which users or processes are\n"
            ."      granted access.\n"
            ."   \$ cryptographic algorithm\n"
            ."      (I) An algorithm that is used to achieve cryptography.\n";

        $terms = (new Rfc4949Parser)->parseDocument($text);

        $this->assertCount(3, $terms);

        $algo = $terms[0];
        $this->assertSame('algorithm', $algo->acronym);
        $this->assertStringContainsString('finite set of step-by-step', $algo->shortDefinition);
        // Gạch nối mềm cuối dòng được nối lại: "problem-" + "solving" -> "problem-solving"
        $this->assertStringContainsString('problem-solving', $algo->shortDefinition);
        $this->assertStringNotContainsString('problem- solving', $algo->shortDefinition);
        // "(I)" marker đã bị bỏ.
        $this->assertStringStartsNotWith('(I)', $algo->shortDefinition);

        $acl = $terms[1];
        $this->assertSame('ACL', $acl->acronym);
        $this->assertSame('access control list', $acl->fullNameEn);
        $this->assertStringContainsString('list of permissions', $acl->shortDefinition);
        // Nhãn miền đầu mục "/network/" và marker "(N)" bị bỏ, không lọt vào định nghĩa.
        $this->assertStringNotContainsString('network', $acl->shortDefinition);
        $this->assertStringStartsNotWith('(', $acl->shortDefinition);
        // Page break giữa hai mục từ không làm vỡ mục "algorithm" (không có "See:" trôi sang ACL).
        $this->assertStringNotContainsString('cryptographic', $acl->shortDefinition);

        // Entry-level attribution + trust.
        $this->assertSame('rfc4949', $acl->source);
        $this->assertSame(1, $acl->authorityTier);
        $this->assertSame(93, $acl->confidence);

        // "(See: cryptographic algorithm.)" được phân giải thành id mục tiêu thật.
        $crypto = $terms[2];
        $this->assertSame([$crypto->id], $algo->relatedSlugs);
        // Mục không có tham chiếu thì không bịa quan hệ.
        $this->assertSame([], $acl->relatedSlugs);
    }

    public function test_source_registry_tiers_and_corroboration(): void
    {
        $this->assertSame(1, SourceRegistry::tier('nist'));
        $this->assertSame(2, SourceRegistry::tier('cncf'));
        $this->assertSame('Public Domain', SourceRegistry::license('nist'));
        $this->assertSame(3, SourceRegistry::tier('unknown'));
        // một nguồn: giữ nguyên; ba nguồn: +4 mỗi nguồn thừa, trần 100
        $this->assertSame(95, SourceRegistry::corroborate(95, 1));
        $this->assertSame(99, SourceRegistry::corroborate(95, 2));
        $this->assertSame(100, SourceRegistry::corroborate(98, 5));
    }

    public function test_concept_key_normalizes_name_and_refuses_empty(): void
    {
        $this->assertSame('accesscontrollist', TermText::conceptKey('Access Control List'));
        $this->assertSame('accesscontrollist', TermText::conceptKey(' access-control-list. '));
        $this->assertNotSame(TermText::conceptKey('access control'), TermText::conceptKey('access control list'));
        // Tên quá dài vẫn nằm trong cột varchar(64).
        $this->assertSame(64, mb_strlen(TermText::conceptKey(str_repeat('long ', 40))));
        // Không có tên => không có khóa, tránh gom sạch những mục trống tên vào một nhúm.
        $this->assertSame('', TermText::conceptKey(''));
        $this->assertSame('', TermText::conceptKey('   '));
        // Tên toàn ký hiệu toán học hoặc quá ngắn: chuẩn hóa sẽ dồn về 1-2 chữ cái
        // và gộp nhầm (|x| với {X} với ⎾x⏋), nên chủ trương không gán khóa.
        $this->assertSame('', TermText::conceptKey('|x|'));
        $this->assertSame('', TermText::conceptKey('{X}'));
        $this->assertSame('', TermText::conceptKey('⎾x⏋'));
        $this->assertSame('', TermText::conceptKey('a'));
        $this->assertSame('', TermText::conceptKey('C++'));
    }

    public function test_clean_strips_bold_links_and_headings(): void
    {
        $raw = "## Heading\nAn **API** is [a contract](/en-US/docs/API) with {{glossary(\"HTTP\",\"methods\")}}.";
        $out = TermText::clean($raw);
        $this->assertStringNotContainsString('**', $out);
        $this->assertStringNotContainsString('[a contract](', $out);
        $this->assertStringNotContainsString('{{glossary', $out);
        $this->assertStringNotContainsString('Heading', $out);
        $this->assertStringContainsString('a contract', $out);
        $this->assertStringContainsString('methods', $out);
    }
}
