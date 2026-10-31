<?php

/*
|--------------------------------------------------------------------------
| Thông báo lỗi kiểm dữ liệu (tiếng Việt)
|--------------------------------------------------------------------------
|
| Chỉ khai báo các quy tắc mà API đang dùng; quy tắc nào thiếu sẽ fallback về
| lang/en của framework nên không làm vỡ response.
|
*/

return [
    'required' => 'Trường :attribute không được để trống.',
    'string' => 'Trường :attribute phải là chuỗi ký tự.',
    'integer' => 'Trường :attribute phải là số nguyên.',
    'boolean' => 'Trường :attribute phải là true hoặc false.',
    'array' => 'Trường :attribute phải là một mảng.',
    'confirmed' => 'Giá trị xác nhận của :attribute không khớp.',
    'email' => 'Trường :attribute phải là địa chỉ email hợp lệ.',

    'min' => [
        'string' => 'Trường :attribute phải có ít nhất :min ký tự.',
        'numeric' => 'Trường :attribute phải lớn hơn hoặc bằng :min.',
        'array' => 'Trường :attribute phải có ít nhất :min phần tử.',
    ],

    'max' => [
        'string' => 'Trường :attribute không được vượt quá :max ký tự.',
        'numeric' => 'Trường :attribute không được lớn hơn :max.',
        'array' => 'Trường :attribute không được có nhiều hơn :max phần tử.',
    ],

    'in' => 'Giá trị đã chọn cho :attribute không hợp lệ.',
    'unique' => 'Giá trị của :attribute đã tồn tại.',
    'exists' => 'Giá trị đã chọn cho :attribute không tồn tại.',

    'attributes' => [
        'q' => 'từ khóa',
        'raw_text' => 'văn bản cần giải mã',
        'review_note' => 'ghi chú kiểm duyệt',
        'last_pulled_at' => 'mốc đồng bộ',
        'page_size' => 'số dòng mỗi lô',
        'cursor' => 'con trỏ phân trang',
        'status' => 'trạng thái',
    ],
];
