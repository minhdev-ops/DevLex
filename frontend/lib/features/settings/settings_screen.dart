import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../core/app_theme.dart';
import '../../core/reminders.dart';
import '../../core/consent.dart';
import '../../core/moderator_config.dart';
import '../../core/theme_controller.dart';
import '../../data/glossary_repository.dart';
import '../legal/privacy_policy_screen.dart';
import '../moderation/moderation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = GlossaryRepository.instance;

  bool _syncing = false;
  late Future<DateTime?> _lastSync;

  late final TextEditingController _serverController;
  String? _serverError;

  late final TextEditingController _moderatorController;
  bool _moderatorSaved = false;

  @override
  void initState() {
    super.initState();
    _lastSync = _repo.lastSyncAt();
    _serverController = TextEditingController(
      text: ApiConfig.instance.baseUrl.value,
    );
    _moderatorController = TextEditingController(
      text: ModeratorConfig.instance.token.value,
    );
    _moderatorSaved = ModeratorConfig.instance.isConfigured;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _moderatorController.dispose();
    super.dispose();
  }

  Future<void> _saveServer() async {
    final error = await ApiConfig.instance.save(_serverController.text);
    if (!mounted) return;
    setState(() {
      _serverError = error;
      _serverController.text = ApiConfig.instance.baseUrl.value;
    });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu địa chỉ máy chủ.')),
      );
    }
  }

  Future<void> _resetServer() async {
    await ApiConfig.instance.reset();
    if (!mounted) return;
    setState(() {
      _serverError = null;
      _serverController.text = ApiConfig.instance.baseUrl.value;
    });
  }

  bool get _consentAccepted => Consent.instance.accepted.value;

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  Future<void> _acceptConsent() async {
    await Consent.instance.accept();
    if (mounted) setState(() {});
  }

  Future<void> _saveModerator() async {
    await ModeratorConfig.instance.save(_moderatorController.text);
    if (!mounted) return;
    setState(() {
      _moderatorSaved = ModeratorConfig.instance.isConfigured;
      _moderatorController.text = ModeratorConfig.instance.token.value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _moderatorSaved ? 'Đã lưu token kiểm duyệt.' : 'Đã gỡ token kiểm duyệt.',
        ),
      ),
    );
  }

  void _openModeration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModerationScreen()),
    );
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final res = await _repo.syncNow();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastSync = _repo.lastSyncAt();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_syncMessage(res))),
    );
  }

  String _syncMessage(SyncOutcome res) {
    if (!res.ok) return 'Không kết nối được máy chủ — app vẫn chạy offline.';
    final summary =
        '${res.updated} thuật ngữ cập nhật, ${res.deleted} thuật ngữ đã xóa.';
    return res.partial
        ? 'Đồng bộ một phần: $summary Sẽ tiếp tục ở lần sau.'
        : 'Đồng bộ xong: $summary';
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt lại tiến độ học?'),
        content: const Text(
          'Toàn bộ trạng thái Đã học / Cần ôn tập, chuỗi streak và lịch ôn sẽ bị xóa. '
          'Kho thuật ngữ offline vẫn giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _repo.resetProgress();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đặt lại tiến độ học trên thiết bị.')),
    );
  }

  Future<void> _toggleReminder(bool value) async {
    await Reminders.instance.setEnabled(value);
    if (!mounted) return;
    setState(() {});
    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sẽ nhắc bạn lúc ${Reminders.instance.time.value.label} mỗi ngày.',
          ),
        ),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    final current = Reminders.instance.time.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await Reminders.instance.setTime(picked.hour, picked.minute);
    if (mounted) setState(() {});
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await AppThemeController.instance.setMode(mode);
    if (mounted) setState(() {});
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = _repo.studyStats();
    final mode = AppThemeController.instance.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt & giới thiệu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SectionCard(
            title: 'Giao diện',
            icon: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn chế độ hiển thị phù hợp khi đọc tài liệu ban đêm.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThemeChoice(
                      icon: Icons.brightness_auto_outlined,
                      label: 'Hệ thống',
                      selected: mode == ThemeMode.system,
                      onTap: () => _setTheme(ThemeMode.system),
                    ),
                    _ThemeChoice(
                      icon: Icons.light_mode_outlined,
                      label: 'Sáng',
                      selected: mode == ThemeMode.light,
                      onTap: () => _setTheme(ThemeMode.light),
                    ),
                    _ThemeChoice(
                      icon: Icons.dark_mode_outlined,
                      label: 'Tối',
                      selected: mode == ThemeMode.dark,
                      onTap: () => _setTheme(ThemeMode.dark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Nhắc học',
            icon: Icons.alarm_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông báo nhắc ôn tập mỗi ngày',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Switch(
                      value: Reminders.instance.enabled.value,
                      onChanged: _toggleReminder,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: Reminders.instance.enabled.value
                      ? _pickReminderTime
                      : null,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    'Giờ nhắc: ${Reminders.instance.time.value.label}',
                  ),
                ),
                if (stats.bestStreak > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 18,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Chuỗi ôn tập tốt nhất: ${stats.bestStreak}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Dữ liệu offline',
            icon: Icons.storage_outlined,
            child: Column(
              children: [
                _InfoRow(
                  label: 'Thuật ngữ trong máy',
                  value: _group(_repo.termCount),
                ),
                _InfoRow(
                  label: 'Biến thể / acronym',
                  value: _group(_repo.aliasCount),
                ),
                _InfoRow(
                  label: 'Khái niệm đa nguồn',
                  value: _group(_repo.corroboratedConceptCount),
                ),
                _InfoRow(
                  label: 'Thẻ đang theo dõi',
                  value: '${stats.tracked} · ${stats.dueNow} đến hạn',
                ),
                FutureBuilder<DateTime?>(
                  future: _lastSync,
                  builder: (context, snapshot) {
                    final at = snapshot.data;
                    return _InfoRow(
                      label: 'Đồng bộ gần nhất',
                      value: at == null ? 'Chưa đồng bộ' : _date(at),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _syncing ? null : _sync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync_outlined),
                    label: Text(_syncing ? 'Đang đồng bộ…' : 'Đồng bộ ngay'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetProgress,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Đặt lại tiến độ học'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Máy chủ đồng bộ',
            icon: Icons.dns_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Địa chỉ backend Laravel (ví dụ http://192.168.1.10:8000). '
                  'Đổi xong áp dụng ngay cho lần đồng bộ và gửi đóng góp kế tiếp.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ máy chủ',
                    hintText: ApiConfig.defaultBaseUrl,
                    border: const OutlineInputBorder(),
                    errorText: _serverError,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saveServer,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Lưu địa chỉ'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Khôi phục mặc định',
                      onPressed: _resetServer,
                      icon: const Icon(Icons.settings_backup_restore),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Kiểm duyệt đóng góp',
            icon: Icons.verified_user_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dành cho moderator: nhập token do quản trị viên cấp để mở hàng chờ '
                  'duyệt đề xuất cộng đồng (FR-COMM-02). Token chỉ lưu trên thiết bị.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _moderatorController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Token moderator',
                    hintText: 'Dán token được cấp',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saveModerator,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_moderatorSaved ? 'Cập nhật token' : 'Lưu token'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Gỡ token',
                      onPressed: _moderatorSaved
                          ? () {
                              _moderatorController.clear();
                              _saveModerator();
                            }
                          : null,
                      icon: const Icon(Icons.lock_open_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _moderatorSaved ? _openModeration : null,
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Mở hàng chờ kiểm duyệt'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Nguồn dữ liệu & bản quyền',
            icon: Icons.account_balance_outlined,
            child: Column(
              children: [
                for (final source in _sources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        source.shortName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      source.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${source.field} · ${source.license}'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openSource(source.url),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Nội dung được biên dịch/tóm tắt sang tiếng Việt và ghi công đa nguồn ở cuối '
                    'mỗi bài. roadmap.sh chỉ dùng để tham khảo cấu trúc, không sao chép văn bản thô.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Quyền riêng tư',
            icon: Icons.privacy_tip_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Chính sách',
                  value: 'Phiên bản ${PrivacyPolicyScreen.version}',
                ),
                _InfoRow(
                  label: 'Trạng thái đồng ý',
                  value: _consentAccepted ? 'Đã đồng ý' : 'Chưa đồng ý',
                ),
                const SizedBox(height: 6),
                Text(
                  'App không yêu cầu đăng nhập, không thu thập vị trí, danh bạ, SMS hay '
                  'dữ liệu phân tích. Tiến độ học chỉ lưu trên thiết bị; dữ liệu chỉ rời '
                  'máy khi bạn chủ động đồng bộ hoặc gửi đóng góp.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openPrivacy,
                    icon: const Icon(Icons.policy_outlined),
                    label: const Text('Đọc chính sách quyền riêng tư'),
                  ),
                ),
                if (!_consentAccepted) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _acceptConsent,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Đồng ý chính sách'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Về DevLex',
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Phiên bản', value: '1.0.0 (1)'),
                _InfoRow(
                  label: 'Mô hình',
                  value: '3 tầng tri thức · 4 lộ trình nghề',
                ),
                _InfoRow(
                  label: 'Chế độ',
                  value: 'Offline-first (SQLite đóng gói)',
                ),
                const SizedBox(height: 8),
                Text(
                  'Được xây dựng theo đặc tả SRS IEEE 830 của dự án DevLex.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _group(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onSurface),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Source {
  const _Source({
    required this.shortName,
    required this.name,
    required this.field,
    required this.license,
    required this.url,
  });

  final String shortName;
  final String name;
  final String field;
  final String license;
  final String url;
}

const _sources = [
  _Source(
    shortName: 'NIST',
    name: 'NIST CSRC Glossary',
    field: 'An toàn thông tin, hệ thống',
    license: 'Public Domain',
    url: 'https://csrc.nist.gov/glossary',
  ),
  _Source(
    shortName: 'MDN',
    name: 'MDN Web Docs Glossary',
    field: 'Web, frontend, API',
    license: 'CC BY-SA 2.5',
    url: 'https://developer.mozilla.org/en-US/docs/Glossary',
  ),
  _Source(
    shortName: 'CNCF',
    name: 'CNCF Cloud Native Glossary',
    field: 'Cloud, DevOps, Kubernetes',
    license: 'CC BY 4.0',
    url: 'https://glossary.cncf.io/',
  ),
  _Source(
    shortName: 'IETF',
    name: 'IETF RFC 4949',
    field: 'An ninh mạng',
    license: 'IETF Trust Legal Provisions',
    url: 'https://www.rfc-editor.org/rfc/rfc4949',
  ),
  _Source(
    shortName: 'RM',
    name: 'roadmap.sh',
    field: 'Cấu trúc lộ trình (tham khảo)',
    license: 'Proprietary — không sao chép',
    url: 'https://roadmap.sh/',
  ),
];

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
