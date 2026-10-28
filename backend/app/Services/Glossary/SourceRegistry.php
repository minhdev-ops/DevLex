<?php

namespace App\Services\Glossary;

/**
 * Danh mục nguồn uy tín: mỗi nguồn có bậc thẩm quyền (authority tier) và
 * độ tin cậy gốc (base confidence 0-100) dùng để chấm điểm "dữ liệu uy tín".
 *
 * Tier 1 = tổ chức chuẩn hóa / chính phủ (NIST, W3C-browsers qua MDN)
 * Tier 2 = liên minh công nghiệp (CNCF)
 */
final class SourceRegistry
{
    /** @var array<string, array{label:string, license:string, author:string, tier:int, confidence:int}> */
    private const SOURCES = [
        'nist' => [
            'label' => 'NIST CSRC Glossary',
            'license' => 'Public Domain',
            'author' => 'NIST / Computer Security Resource Center',
            'tier' => 1,
            'confidence' => 95,
        ],
        'mdn' => [
            'label' => 'MDN Web Docs',
            'license' => 'CC BY-SA 2.5',
            'author' => 'Mozilla Contributors',
            'tier' => 1,
            'confidence' => 88,
        ],
        'cncf' => [
            'label' => 'CNCF Cloud Native Glossary',
            'license' => 'CC BY 4.0',
            'author' => 'Cloud Native Glossary Authors',
            'tier' => 2,
            'confidence' => 80,
        ],
    ];

    /** @return array{label:string, license:string, author:string, tier:int, confidence:int} */
    public static function get(string $source): array
    {
        return self::SOURCES[strtolower($source)] ?? [
            'label' => $source,
            'license' => '',
            'author' => '',
            'tier' => 3,
            'confidence' => 50,
        ];
    }

    public static function label(string $source): string
    {
        return self::get($source)['label'];
    }

    public static function license(string $source): string
    {
        return self::get($source)['license'];
    }

    public static function author(string $source): string
    {
        return self::get($source)['author'];
    }

    public static function tier(string $source): int
    {
        return self::get($source)['tier'];
    }

    public static function confidence(string $source): int
    {
        return self::get($source)['confidence'];
    }

    /**
     * Chấm lại độ tin cậy khi cùng một khái niệm được nhiều nguồn uy tín xác nhận.
     * Mỗi nguồn bổ sung +4, tối đa 100.
     *
     * @param  int  $baseConfidence  confidence của nguồn gốc
     * @param  int  $agreeingSources  số nguồn độc lập cùng định nghĩa (>=1)
     */
    public static function corroborate(int $baseConfidence, int $agreeingSources): int
    {
        return min(100, $baseConfidence + 4 * max(0, $agreeingSources - 1));
    }
}
