<?php

namespace Database\Seeders;

use App\Models\Term;
use App\Models\TermAlias;
use Illuminate\Database\Seeder;

class TermSeeder extends Seeder
{
    public function run(): void
    {
        $mdn = fn (string $path, string $component) => [
            'component' => $component,
            'source' => 'MDN Web Docs',
            'author' => 'Mozilla Contributors',
            'license' => 'CC BY-SA 2.5',
            'author_link' => $path,
            'modification_status' => 'Nội dung gốc đã được dịch sang tiếng Việt và đơn giản hóa bởi Hệ thống IT Glossary',
        ];

        $cncf = fn (string $path, string $component) => [
            'component' => $component,
            'source' => 'CNCF Cloud Native Glossary',
            'author' => 'Cloud Native Glossary Authors',
            'license' => 'CC BY 4.0',
            'author_link' => $path,
            'modification_status' => 'Nội dung gốc đã được dịch sang tiếng Việt',
        ];

        $nist = fn (string $component) => [
            'component' => $component,
            'source' => 'NIST CSRC Glossary',
            'author' => 'NIST CSRC',
            'license' => 'Public Domain',
            'author_link' => 'https://csrc.nist.gov/glossary',
            'modification_status' => 'Nội dung gốc đã được dịch sang tiếng Việt và tóm tắt',
        ];

        $terms = [
            [
                'id' => 'term_api_001',
                'tier_1_acronym' => 'API',
                'tier_1_full_name_en' => 'Application Programming Interface',
                'tier_1_full_name_vi' => 'Giao diện Lập trình Ứng dụng',
                'tier_1_short_definition' => 'Quy tắc cho phép các ứng dụng phần mềm giao tiếp và truyền nhận dữ liệu với nhau.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nAPI đóng vai trò cầu nối giữa ứng dụng Client và Server. Trong quy trình phát triển phần mềm, API được thiết kế ở giai đoạn Back-end, được kiểm thử bằng integration test và được frontend hoặc các dịch vụ khác gọi qua HTTP.",
                'tier_2_metaphor_analogy' => 'API hoạt động giống như một người phục vụ nhà hàng: tiếp nhận yêu cầu từ khách hàng, truyền tới nhà bếp và mang kết quả quay trở lại.',
                'tier_2_diagram_url' => null,
                'tier_3_category_tags' => ['Backend', 'Web Service', 'Architecture'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => ['term_http_002'],
                'tier_3_related_terms' => ['term_rest_010', 'term_json_005', 'term_jwt_008'],
                'roadmap_career' => 'backend',
                'source_attribution' => [$nist('tier_1'), $mdn('https://developer.mozilla.org/en-US/docs/Glossary/API', 'tier_2')],
            ],
            [
                'id' => 'term_http_002',
                'tier_1_acronym' => 'HTTP',
                'tier_1_full_name_en' => 'Hypertext Transfer Protocol',
                'tier_1_full_name_vi' => 'Giao thức truyền tải siêu văn bản',
                'tier_1_short_definition' => 'Giao thức truyền tin cậy nền tảng của Web, quy định cách client và server trao đổi yêu cầu/phản hồi.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nMỗi khi trình duyệt tải một trang web, nó gửi HTTP request tới server và nhận HTTP response kèm mã trạng thái (200, 404, 500...). API hiện đại gần như luôn chạy trên HTTP.",
                'tier_2_metaphor_analogy' => 'HTTP giống như quy ước ngôn ngữ chung khi gọi điện tổng đài: nhấc máy (kết nối), nói mã số yêu cầu (method + URL), nhận trả lời (response).',
                'tier_3_category_tags' => ['Network', 'Web'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => [],
                'tier_3_related_terms' => ['term_api_001', 'term_rest_010', 'term_json_005'],
                'roadmap_career' => 'backend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Web/HTTP', 'tier_1')],
            ],
            [
                'id' => 'term_json_005',
                'tier_1_acronym' => 'JSON',
                'tier_1_full_name_en' => 'JavaScript Object Notation',
                'tier_1_full_name_vi' => 'Ký pháp đối tượng JavaScript',
                'tier_1_short_definition' => 'Định dạng văn bản nhỏ gọn, dễ đọc, chuẩn mở để trao đổi dữ liệu giữa các hệ thống.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nJSON là định dạng payload phổ biến nhất của Web API hiện đại: request body, response body, cấu hình file, và dữ liệu lưu trong NoSQL.",
                'tier_2_metaphor_analogy' => 'JSON giống như mẫu đơn chuẩn in sẵn: mọi người đều biết điền và đọc, không cần giải thích thêm.',
                'tier_3_category_tags' => ['Data Format', 'Web'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => [],
                'tier_3_related_terms' => ['term_api_001', 'term_rest_010'],
                'roadmap_career' => 'frontend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Web/JSON', 'tier_1')],
            ],
            [
                'id' => 'term_rest_010',
                'tier_1_acronym' => 'REST',
                'tier_1_full_name_en' => 'Representational State Transfer',
                'tier_1_full_name_vi' => 'Chuyển trạng thái biểu diễn',
                'tier_1_short_definition' => 'Kiến trúc thiết kế API sử dụng các phương thức HTTP tiêu chuẩn (GET, POST, PUT, DELETE) trên tài nguyên định danh bằng URL.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nREST API là lựa chọn mặc định khi xây dựng backend service. Mỗi tài nguyên (user, order) là một URL; hành động là HTTP method; trạng thái trả về qua HTTP status code.",
                'tier_2_metaphor_analogy' => 'REST giống hệ thống thư viện: tra sách theo mã giá (URL), mượn/trả theo quy trình cố định (method), nhận biên nhận (status code).',
                'tier_3_category_tags' => ['Backend', 'Architecture'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => ['term_api_001', 'term_http_002'],
                'tier_3_related_terms' => ['term_json_005', 'term_jwt_008'],
                'roadmap_career' => 'backend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Glossary/REST', 'tier_1')],
            ],
            [
                'id' => 'term_jwt_008',
                'tier_1_acronym' => 'JWT',
                'tier_1_full_name_en' => 'JSON Web Token',
                'tier_1_full_name_vi' => 'Chuẩn token JSON Web',
                'tier_1_short_definition' => 'Chuẩn mở định dạng mã hóa an toàn dùng để truyền thông tin xác thực người dùng giữa hai bên.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nSau khi đăng nhập, server phát JWT cho client; client đính kèm token trong header Authorization của mọi request tiếp theo. Server chỉ cần verify chữ ký, không phải tra session.",
                'tier_2_metaphor_analogy' => 'JWT giống vòng tay lễ hội có chữ ký bảo vệ: ban tổ chức không cần kiểm tra lại danh tính mỗi lần bạn qua cổng, chỉ cần xác nhận vòng tay còn hiệu lực.',
                'tier_3_category_tags' => ['Security', 'Backend', 'Web Service'],
                'tier_3_difficulty_level' => 'Intermediate',
                'tier_3_prerequisites' => ['term_api_001', 'term_json_005'],
                'tier_3_related_terms' => ['term_rest_010'],
                'roadmap_career' => 'backend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Glossary/JWT', 'tier_1'), $nist('tier_2')],
            ],
            [
                'id' => 'term_k8s_001',
                'tier_1_acronym' => 'Kubernetes',
                'tier_1_full_name_en' => 'Kubernetes',
                'tier_1_full_name_vi' => 'Hệ thống điều phối Container Kubernetes',
                'tier_1_short_definition' => 'Nền tảng mã nguồn mở tự động hóa việc triển khai, mở rộng và quản lý ứng dụng container.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nTrong quy trình DevOps, sau khi app được đóng gói thành Docker image và đẩy qua CI/CD pipeline, Kubernetes (K8s) nhận trách nhiệm chạy các container đó trên cụm server: tự cân bằng tải, tự khởi động lại khi lỗi, tự scale theo lưu lượng.",
                'tier_2_metaphor_analogy' => 'K8s giống một điều phối viên dàn nhạc giao hưởng: mỗi container là một nhạc công, K8s quyết định ai chơi lúc nào, và nếu ai đó rời ghế thì lập tức có người thay.',
                'tier_3_category_tags' => ['DevOps', 'Cloud Native'],
                'tier_3_difficulty_level' => 'Advanced',
                'tier_3_prerequisites' => ['term_docker_020'],
                'tier_3_related_terms' => ['term_cicd_021', 'term_iaas_022'],
                'roadmap_career' => 'devops',
                'source_attribution' => [$cncf('https://github.com/cncf/glossary/blob/main/glossary/kubernetes.yaml', 'tier_1')],
            ],
            [
                'id' => 'term_docker_020',
                'tier_1_acronym' => 'Docker',
                'tier_1_full_name_en' => 'Docker',
                'tier_1_full_name_vi' => 'Nền tảng đóng gói Container',
                'tier_1_short_definition' => 'Công cụ đóng gói ứng dụng cùng toàn bộ phụ thuộc vào container chạy độc lập trên mọi môi trường.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nDocker giải quyết vấn đề 'chạy được trên máy tôi nhưng hỏng trên server': môi trường phát triển, staging và production dùng chung một image.",
                'tier_2_metaphor_analogy' => 'Container Docker giống container vận tải biển: bên trong chứa gì không quan trọng, mọi cần cẩu (máy chủ) đều xử lý cùng một kích thước chuẩn.',
                'tier_3_category_tags' => ['DevOps', 'Cloud Native'],
                'tier_3_difficulty_level' => 'Intermediate',
                'tier_3_prerequisites' => [],
                'tier_3_related_terms' => ['term_k8s_001', 'term_cicd_021'],
                'roadmap_career' => 'devops',
                'source_attribution' => [$cncf('https://github.com/cncf/glossary/blob/main/glossary/container.yaml', 'tier_1')],
            ],
            [
                'id' => 'term_cicd_021',
                'tier_1_acronym' => 'CI/CD',
                'tier_1_full_name_en' => 'Continuous Integration / Continuous Delivery',
                'tier_1_full_name_vi' => 'Tích hợp liên tục / Phân phối liên tục',
                'tier_1_short_definition' => 'Quy trình tự động build, test và phát hành mã nguồn mỗi khi có thay đổi được hợp nhất.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nMỗi Pull Request kích hoạt pipeline: build → unit test → integration test → deploy staging. Lỗi được phát hiện trong phút thay vì cuối sprint.",
                'tier_2_metaphor_analogy' => 'CI/CD giống dây chuyền kiểm tra chất lượng nhà máy: mỗi sản phẩm (code) mới đều qua cùng một chuỗi test tự động trước khi đóng gói.',
                'tier_3_category_tags' => ['DevOps'],
                'tier_3_difficulty_level' => 'Intermediate',
                'tier_3_prerequisites' => ['term_docker_020'],
                'tier_3_related_terms' => ['term_k8s_001', 'term_scrum_030'],
                'roadmap_career' => 'devops',
                'source_attribution' => [$cncf('https://github.com/cncf/glossary/blob/main/glossary/continuous_integration.yaml', 'tier_1')],
            ],
            [
                'id' => 'term_iaas_022',
                'tier_1_acronym' => 'IaaS',
                'tier_1_full_name_en' => 'Infrastructure as a Service',
                'tier_1_full_name_vi' => 'Hạ tầng như một dịch vụ',
                'tier_1_short_definition' => 'Mô hình thuê hạ tầng máy chủ, lưu trữ, mạng theo dùng bao nhiêu trả tiền bấy nhiêu thay vì tự mua phần cứng.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nIaaS là tầng dưới cùng của đám mây (kèm PaaS, SaaS): team DevOps khởi tạo VM/VPC trên AWS/Azure thay vì đặt server vật lý trong phòng máy.",
                'tier_2_metaphor_analogy' => 'IaaS giống thuê đất trống xây nhà: điện nước (phần cứng) có sẵn, bạn tự quyết định xây gì trên đó.',
                'tier_3_category_tags' => ['Cloud'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => [],
                'tier_3_related_terms' => ['term_k8s_001'],
                'roadmap_career' => 'devops',
                'source_attribution' => [$nist('tier_1'), $cncf('https://github.com/cncf/glossary/blob/main/glossary/iaas.yaml', 'tier_2')],
            ],
            [
                'id' => 'term_spa_040',
                'tier_1_acronym' => 'SPA',
                'tier_1_full_name_en' => 'Single Page Application',
                'tier_1_full_name_vi' => 'Ứng dụng một trang',
                'tier_1_short_definition' => 'Web app chỉ tải một trang HTML duy nhất, cập nhật nội dung động qua JavaScript và API.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nReact/Vue/Angular dựng SPA: điều hướng và dữ liệu được fetch qua API mà không tải lại trang, cho trải nghiệm mượt như app native.",
                'tier_2_metaphor_analogy' => 'SPA giống nhà hàng buffet: bạn vào cửa một lần (tải trang), rồi tự lấy món (gọi API) mà không cần quay ra cửa lại.',
                'tier_3_category_tags' => ['Frontend', 'Web'],
                'tier_3_difficulty_level' => 'Intermediate',
                'tier_3_prerequisites' => ['term_api_001', 'term_json_005'],
                'tier_3_related_terms' => ['term_ssr_041'],
                'roadmap_career' => 'frontend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Glossary/SPA', 'tier_1')],
            ],
            [
                'id' => 'term_ssr_041',
                'tier_1_acronym' => 'SSR',
                'tier_1_full_name_en' => 'Server-Side Rendering',
                'tier_1_full_name_vi' => 'Kết xuất phía máy chủ',
                'tier_1_short_definition' => 'Kỹ thuật dựng HTML đầy đủ trên server trước khi gửi cho trình duyệt, cải thiện tốc độ tải đầu và SEO.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nNext.js/Nuxt dùng SSR để người dùng thấy nội dung ngay lần tải đầu, khắc phục điểm yếu SEO của SPA thuần.",
                'tier_2_metaphor_analogy' => 'SSR giống đặt bánh_online: bánh đã nướng xong giao tận nơi (HTML hoàn chỉnh) thay vì gửi nguyên liệu buộc bạn tự nướng (SPA).',
                'tier_3_category_tags' => ['Frontend', 'Web'],
                'tier_3_difficulty_level' => 'Intermediate',
                'tier_3_prerequisites' => ['term_spa_040'],
                'tier_3_related_terms' => [],
                'roadmap_career' => 'frontend',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/Glossary/Server-side_rendering', 'tier_1')],
            ],
            [
                'id' => 'term_scrum_030',
                'tier_1_acronym' => 'Scrum',
                'tier_1_full_name_en' => 'Scrum',
                'tier_1_full_name_vi' => 'Khung làm việc Agile theo Sprint',
                'tier_1_short_definition' => 'Khung làm việc Agile chia dự án thành các Sprint ngắn, kèm lễ họp đứng, lập kế hoạch và retrospective.',
                'tier_2_detailed_explanation' => "### Ngữ cảnh vận hành\nTeam nhận backlog, cắt thành Sprint 1–2 tuần; mỗi ngày daily standup; kết thúc sprint là demo + retrospective. Pull Request và Code Review là luồng phối hợp kỹ thuật trong Sprint.",
                'tier_2_metaphor_analogy' => 'Scrum giống đội rowing: mọi người chèo theo cùng nhịp đếm (sprint), thuyền trưởng chỉnh hướng sau mỗi chặng (retrospective).',
                'tier_3_category_tags' => ['Process', 'Communication'],
                'tier_3_difficulty_level' => 'Beginner',
                'tier_3_prerequisites' => [],
                'tier_3_related_terms' => ['term_cicd_021'],
                'roadmap_career' => 'project_comm',
                'source_attribution' => [$mdn('https://developer.mozilla.org/en-US/docs/MDN_Community/MDN_Policies/Scrum_process', 'tier_1')],
            ],
        ];

        foreach ($terms as $row) {
            Term::query()->updateOrCreate(['id' => $row['id']], $row);
        }

        $aliases = [
            ['term_id' => 'term_k8s_001', 'alias' => 'k8s', 'naming_rule_note' => 'Quy ước numeronym: chữ K đầu + số 8 (thay cho 8 ký tự "ubernete" ở giữa) + chữ s cuối.'],
            ['term_id' => 'term_spa_040', 'alias' => 'spa', 'naming_rule_note' => 'Từ viết tắt giữ nguyên: Single Page Application.'],
            ['term_id' => 'term_cicd_021', 'alias' => 'cicd', 'naming_rule_note' => 'Viết tắt không dấu gạch chéo: Continuous Integration / Continuous Delivery.'],
            ['term_id' => 'term_iaas_022', 'alias' => 'iaas', 'naming_rule_note' => 'Cấu trúc X-aaS: Infrastructure as a Service.'],
        ];

        foreach ($aliases as $row) {
            TermAlias::query()->updateOrCreate(['alias' => $row['alias']], $row);
        }
    }
}
