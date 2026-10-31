import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/consent.dart';
import 'privacy_policy_screen.dart';

/// Banner xin đồng ý chính sách quyền riêng tư ở lần mở app đầu tiên.
///
/// Google Play yêu cầu người dùng được thông báo trước khi dùng ứng dụng; app
/// không thu thập PII nên banner chỉ tóm tắt và mở link tới chính sách đầy đủ.
Future<void> showConsentSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (sheetContext) => const _ConsentSheet(),
  );
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trước khi bắt đầu',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'DevLex chạy hoàn toàn offline. Kho thuật ngữ và tiến độ học của '
              'bạn nằm trên thiết bị này.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            for (final line in const [
              'Không tài khoản, không quảng cáo, không theo dõi hành vi.',
              'Không xin quyền vị trí, danh bạ, SMS hay tệp trong máy.',
              'Chỉ gửi dữ liệu lên máy chủ khi bạn chủ động đồng bộ hoặc gửi '
                  'đóng góp.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
              child: const Text('Đọc chính sách đầy đủ'),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await Consent.instance.accept();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Đã hiểu và đồng ý'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
