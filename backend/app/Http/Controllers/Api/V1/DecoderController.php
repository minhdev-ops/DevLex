<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DecoderController extends Controller
{
    /**
     * FR-DEC-01: tách từ, khớp toàn bộ thuật ngữ/acronym trong một lượt
     * (load dictionary vào bộ nhớ để chống N+1 query — SRS mục 5).
     */
    public function extract(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'raw_text' => ['required', 'string', 'max:10000'],
        ]);

        $text = $validated['raw_text'];

        // Build dictionary một lần: acronym + alias -> term.
        $dictionary = [];
        foreach (Term::all(['id', 'tier_1_acronym', 'tier_1_full_name_en', 'tier_1_short_definition']) as $term) {
            $key = $this->normalize($term->tier_1_acronym);
            if ($key !== '') {
                $dictionary[$key] = $term;
            }
        }
        foreach (TermAlias::with('term')->get() as $alias) {
            if ($alias->term) {
                $dictionary[$this->normalize($alias->alias)] = $alias->term;
            }
        }

        $extracted = [];
        // Token hóa giữ index để trả về vị trí start/end.
        if (preg_match_all('/[A-Za-z0-9\/]+/u', $text, $matches, PREG_OFFSET_CAPTURE)) {
            $seen = [];
            foreach ($matches[0] as $match) {
                [$token, $offset] = $match;
                $term = $dictionary[$this->normalize($token)] ?? null;
                if (! $term || isset($seen[$term->id])) {
                    continue;
                }
                $seen[$term->id] = true;

                $extracted[] = [
                    'term_id' => $term->id,
                    'acronym' => $term->tier_1_acronym,
                    'full_name_en' => $term->tier_1_full_name_en,
                    'short_definition' => $term->tier_1_short_definition,
                    'position' => ['start' => $offset, 'end' => $offset + strlen($token)],
                ];
            }
        }

        return response()->json([
            'status' => 'success',
            'extracted_terms' => $extracted,
        ]);
    }

    private function normalize(string $value): string
    {
        return mb_strtolower(preg_replace('/[\s\-_.,\/]+/', '', $value));
    }
}
