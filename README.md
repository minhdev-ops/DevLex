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

- Stack: Laravel 12, PHP 8.2, PostgreSQL (dev dùng SQLite).
- API: `/api/v1/terms/search`, `/api/v1/terms/{id}` (schema 3 tầng + `source_attribution`).

```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate
php artisan migrate --seed
php artisan serve
```

## Frontend (`frontend/`)

- Stack: Flutter (Dart), sqflite — Offline-first, DB đóng gói sẵn trong asset.
- Tính năng MVP: Instant Search (<50ms), Fuzzy Search (Levenshtein), ánh xạ acronym (K8s → Kubernetes), hiển thị 3 tầng + ghi công bản quyền.

```bash
cd frontend
flutter pub get
flutter run
```

## Bản quyền dữ liệu

Nội dung thuật ngữ dẫn nguồn mở (MDN CC BY-SA 2.5, CNCF CC BY 4.0, NIST Public Domain) kèm mô-đun ghi công tự động; roadmap.sh chỉ tham khảo cấu trúc, không sao chép văn bản thô.
