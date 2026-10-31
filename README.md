# DevLex — IT Glossary & Roadmap

Mobile app tra cứu thuật ngữ IT theo mô hình tri thức 3 tầng (Định nghĩa → Bối cảnh & Trực quan → Sơ đồ mối quan hệ & Lộ trình), kèm lộ trình học tập theo nghề (Frontend / Backend / DevOps / Project Communication).

Xem đặc tả chi tiết: `docs/srs.txt`.

## Cấu trúc repository

```
backend/     # Laravel REST API + PostgreSQL (CSDL trung tâm, pipeline dữ liệu)
frontend/    # Flutter app (Android, offline-first với SQLite cục bộ)
docs/        # Tài liệu SRS
```

## Backend (`backend/`)

- Stack: Laravel 12, PHP 8.2, MySQL/PostgreSQL (test chạy trên MySQL).
- API: `/api/v1/terms/search`, `/api/v1/terms/{id}` (schema 3 tầng + `source_attribution`), `/api/v1/decoder/extract`, `/api/v1/sync/delta`, `/api/v1/contributions`.
- Mọi route `/api` luôn trả JSON (kể cả lỗi validation) và thông báo lỗi bằng tiếng Việt.
- Đồng bộ delta trả theo lô (`has_more` + `next_cursor`), kèm `deleted_ids` nhờ xóa mềm để client offline dọn được dữ liệu cũ.
- Endpoint kiểm duyệt (`GET /contributions`, `approve`, `reject`) yêu cầu `Authorization: Bearer $MODERATION_API_TOKEN`.

```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate
php artisan migrate --seed
php artisan serve
```

## Frontend (`frontend/`)

- Stack: Flutter (Dart), sqflite — Offline-first, DB đóng gói sẵn trong asset.
- Kho dữ liệu: hơn 6.500 thuật ngữ từ NIST, MDN, CNCF, IETF RFC 4949 và phần biên soạn DevLex.

### Chức năng đã hoàn thiện

- **Tra cứu (FR-GLOS-01..04):** instant search dưới 50ms trên toàn kho, fuzzy Levenshtein, ánh xạ acronym (K8s → Kubernetes kèm chú thích quy ước numeronym), gộp kết quả cùng khái niệm và hiển thị đủ 3 tầng tri thức.
- **Dashboard:** thẻ đến hạn, "Tiếp tục học", tiến độ 4 lộ trình nghề, thuật ngữ phổ biến và lối tắt sang các tab.
- **Lộ trình (FR-MAP-01..03):** sơ đồ nút tương tác pan/zoom, làm nổi bật nhánh tiên quyết, gợi ý thuật ngữ kế tiếp, đánh dấu Đã học / Cần ôn tập và tính % hoàn thành.
- **Giải mã ngữ cảnh (FR-DEC-01..03):** dán JD/văn bản, highlight thuật ngữ, popover Tầng 1 tại chỗ, danh sách chip và điều hướng sang bài chi tiết.
- **Ôn tập (FR-QUIZ-01..03):** flashcard SRS 1 → 3 → 7 ngày, trắc nghiệm 5–10 câu đảo chiều, phản hồi đúng/sai, thống kê tiến trình ghi nhớ, streak và điểm động lực.
- **Đóng góp (FR-COMM-01..03):** biểu mẫu gửi hàng chờ kiểm duyệt, giữ tên người gửi, mã theo dõi và ghi công sau khi duyệt.
- **Kiểm duyệt trong app (FR-COMM-02):** nhập token moderator ở **Cài đặt → Kiểm duyệt đóng góp** rồi mở hàng chờ: lọc theo trạng thái, duyệt ngay hoặc từ chối kèm lý do (bắt buộc), kéo xuống để tải lại. Thiếu token thì màn hình chỉ hiện hướng dẫn, không gọi mạng.
- **Đồng bộ tự động:** app tự kéo delta khi mở lại nếu lần đồng bộ trước đã quá 6 giờ (và ở lần mở đầu tiên), chạy im lặng nên không chặn UI; vẫn giữ nút "Đồng bộ ngay" để ép chạy.
- **Tuân thủ Google Play:** banner đồng ý quyền riêng tư ở lần mở đầu tiên (lưu trong máy, hỏi lại khi đổi phiên bản chính sách) và trang **Chính sách quyền riêng tư** đọc được offline; chỉ xin quyền INTERNET + ACCESS_NETWORK_STATE.
- **Cài đặt & tuân thủ:** chế độ Sáng/Tối/Hệ thống, đồng bộ delta (báo rõ khi chỉ đồng bộ được một phần), đặt lại tiến độ, cấu hình địa chỉ máy chủ và token kiểm duyệt ngay trong app, danh sách nguồn + giấy phép, chính sách quyền riêng tư.

```bash
cd frontend
flutter pub get
flutter run
# Trỏ tới backend khác (mặc định Android emulator dùng http://10.0.2.2:8000):
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Địa chỉ máy chủ cũng đổi được trực tiếp trong **Cài đặt → Máy chủ đồng bộ** mà không cần build lại.

### Kiểm thử

```bash
cd frontend
flutter analyze
flutter test

cd ../backend
php artisan test
```

## Bản quyền dữ liệu

Nội dung thuật ngữ dẫn nguồn mở (MDN CC BY-SA 2.5, CNCF CC BY 4.0, NIST Public Domain) kèm mô-đun ghi công tự động; roadmap.sh chỉ tham khảo cấu trúc, không sao chép văn bản thô.
