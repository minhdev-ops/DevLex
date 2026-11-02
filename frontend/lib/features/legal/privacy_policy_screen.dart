import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Chính sách quyền riêng tư đầy đủ (Google Play: Privacy Policy).
///
/// Toàn bộ nội dung nằm trong app nên đọc được cả khi offline — Play yêu cầu
/// chính sách phải truy cập được trước khi người dùng dùng ứng dụng.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String version = '1.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Chính sách quyền riêng tư')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'DevLex · Phiên bản $version',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final section in _sections) ...[
            _Section(section: section),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tóm tắt một dòng: app không có tài khoản, không quảng cáo, không '
              'theo dõi; dữ liệu chỉ rời thiết bị khi bạn chủ động đồng bộ hoặc '
              'gửi đóng góp.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final line in section.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PolicySection {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
}

const _sections = [
  _PolicySection(
    icon: Icons.phone_android_outlined,
    title: 'Dữ liệu lưu trên thiết bị',
    lines: [
      'Kho thuật ngữ offline (SQLite) đi kèm bộ cài đặt.',
      'Tiến độ học: trạng thái Đã học / Cần ôn tập, lịch ôn 1–3–7 ngày, chuỗi '
          'streak và điểm.',
      'Tên người đóng góp bạn tự nhập, địa chỉ máy chủ và token kiểm duyệt '
          '(nếu bạn là moderator).',
    ],
  ),
  _PolicySection(
    icon: Icons.cloud_upload_outlined,
    title: 'Khi nào dữ liệu rời thiết bị',
    lines: [
      'Đồng bộ delta: app gửi mốc thời gian đồng bộ cuối và nhận về danh sách '
          'thuật ngữ thay đổi. Không gửi tiến độ học của bạn.',
      'Gửi đóng góp: chỉ nội dung bạn nhập trong biểu mẫu (acronym, tên đầy đủ, '
          'định nghĩa, ví dụ, tên người gửi).',
      'Kiểm duyệt: khi bạn mở hàng chờ, app gửi token moderator để máy chủ xác '
          'thực; nội dung hàng chờ chỉ tải về, không tải lên.',
    ],
  ),
  _PolicySection(
    icon: Icons.block_outlined,
    title: 'Dữ liệu chúng tôi không thu thập',
    lines: [
      'Không vị trí, danh bạ, SMS, ảnh hay tệp trong máy.',
      'Không tài khoản, không mật khẩu, không số điện thoại, không email.',
      'Không SDK quảng cáo, không analytics theo dõi hành vi, không định danh '
          'quảng cáo.',
    ],
  ),
  _PolicySection(
    icon: Icons.security_outlined,
    title: 'Quyền ứng dụng & bảo mật',
    lines: [
      'Chỉ yêu cầu INTERNET và ACCESS_NETWORK_STATE.',
      'Toàn bộ dữ liệu truyền tải đi qua HTTPS/TLS khi máy chủ được cấu hình '
          'đúng; app không gửi dữ liệu tới bất kỳ bên thứ ba nào.',
    ],
  ),
  _PolicySection(
    icon: Icons.copyright_outlined,
    title: 'Bản quyền nội dung',
    lines: [
      'Thuật ngữ dẫn nguồn mở: NIST CSRC (Public Domain), MDN (CC BY-SA 2.5), '
          'CNCF (CC BY 4.0), IETF RFC 4949.',
      'Mỗi bài viết có mô-đun ghi công đa nguồn ở cuối, kèm liên kết bài gốc và '
          'giấy phép.',
      'roadmap.sh chỉ dùng để tham khảo cấu trúc lộ trình, không sao chép văn '
          'bản thô.',
    ],
  ),
  _PolicySection(
    icon: Icons.delete_outline,
    title: 'Xóa dữ liệu của bạn',
    lines: [
      'Cài đặt → Dữ liệu offline → Đặt lại tiến độ học: xóa toàn bộ trạng thái '
          'học, streak và lịch ôn trên thiết bị.',
      'Gỡ ứng dụng sẽ xóa toàn bộ dữ liệu cục bộ.',
      'Nội dung đã gửi lên hàng chờ kiểm duyệt có thể yêu cầu xóa bằng cách '
          'liên hệ quản trị viên kèm mã đề xuất.',
    ],
  ),
];
