<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class StoreContributionRequest extends FormRequest
{
    public function authorize(): bool
    {
        // MVP: cho phép khách gửi đề xuất; hàng chờ kiểm duyệt là lớp an toàn.
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'contributor_name' => ['required', 'string', 'min:2', 'max:120'],
            'tier_1_acronym' => ['required', 'string', 'max:100'],
            'tier_1_full_name_en' => ['required', 'string', 'max:255'],
            'tier_1_short_definition' => ['required', 'string', 'max:2000'],
            'tier_2_detailed_explanation' => ['nullable', 'string', 'max:20000'],
        ];
    }

    public function attributes(): array
    {
        return [
            'contributor_name' => 'tên người đóng góp',
            'tier_1_acronym' => 'từ viết tắt',
            'tier_1_full_name_en' => 'tên đầy đủ tiếng Anh',
            'tier_1_short_definition' => 'định nghĩa ngắn',
        ];
    }
}
