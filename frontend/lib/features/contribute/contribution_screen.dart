import 'package:flutter/material.dart';

import '../../core/contribution_draft.dart';
import '../../data/api_client.dart';
import '../../data/local/glossary_database.dart';

/// Ghi nhớ tên người đóng góp giữa các phiên (FR-COMM-01: không bắt buộc tài khoản).
abstract class ContributorNameStore {
  const ContributorNameStore();

  Future<String?> read();

  Future<void> write(String name);
}

class SqliteContributorNameStore extends ContributorNameStore {
  const SqliteContributorNameStore();

  @override
  Future<String?> read() => GlossaryDatabase.instance.getContributorName();

  @override
  Future<void> write(String name) => GlossaryDatabase.instance.setContributorName(name);
}

/// FR-COMM-01: biểu mẫu gửi đề xuất vào hàng chờ kiểm duyệt.
class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, this.api, this.nameStore});

  final ApiClient? api;
  final ContributorNameStore? nameStore;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _acronym = TextEditingController();
  final _fullName = TextEditingController();
  final _shortDef = TextEditingController();
  final _detail = TextEditingController();

  late final ApiClient _api = widget.api ?? ApiClient();
  late final ContributorNameStore _store = widget.nameStore ?? const SqliteContributorNameStore();

  bool _submitting = false;
  String? _sentId;

  @override
  void initState() {
    super.initState();
    _restoreName();
  }

  Future<void> _restoreName() async {
    final saved = await _store.read();
    if (mounted && saved != null && saved.isNotEmpty && _name.text.isEmpty) {
      _name.text = saved;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _acronym.dispose();
    _fullName.dispose();
    _shortDef.dispose();
    _detail.dispose();
    super.dispose();
  }

  ContributionDraft _draft() => ContributionDraft(
    contributorName: _name.text,
    acronym: _acronym.text,
    fullNameEn: _fullName.text,
    shortDefinition: _shortDef.text,
    detailedExplanation: _detail.text,
  );

  /// Một nguồn kiểm duy nhất: ContributionDraft, dùng lại cho cả UI lẫn body gửi đi.
  String? _errorFor(String field) => _draft().validate()[field];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final res = await _api.submitContribution(_draft().toJson());
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _sentId = res.ok ? (res.id ?? 'đã gửi') : null;
    });
    if (!res.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message), backgroundColor: Colors.red.shade700));
      return;
    }
    await _store.write(_draft().contributorName);
    for (final c in [_acronym, _fullName, _shortDef, _detail]) {
      c.clear();
    }
  }

  void _startAnother() => setState(() => _sentId = null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đóng góp thuật ngữ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_sentId != null)
              _SentCard(contributionId: _sentId!, onAnother: _startAnother)
            else ...[
              _HowItWorksCard(tone: scheme.secondaryContainer),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên người đóng góp',
                hintText: 'Tên sẽ xuất hiện trong phần ghi công',
                border: OutlineInputBorder(),
              ),
              validator: (_) => _errorFor('contributorName'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _acronym,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Từ viết tắt (Tầng 1)',
                hintText: 'VD: gRPC',
                border: OutlineInputBorder(),
              ),
              validator: (_) => _errorFor('acronym'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên đầy đủ tiếng Anh',
                hintText: 'VD: gRPC Remote Procedure Call',
                border: OutlineInputBorder(),
              ),
              validator: (_) => _errorFor('fullNameEn'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortDef,
              maxLines: 3,
              maxLength: ContributionDraft.maxShort,
              decoration: const InputDecoration(
                labelText: 'Định nghĩa ngắn (Tầng 1)',
                hintText: '1–2 câu, nói rõ nó là gì và dùng khi nào',
                border: OutlineInputBorder(),
              ),
              validator: (_) => _errorFor('shortDefinition'),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _detail,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Giải thích chi tiết (Tầng 2, không bắt buộc)',
                hintText: 'Ví dụ, luồng hoạt động, sai lầm thường gặp',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Đang gửi…' : 'Gửi đề xuất'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.tone});

  final Color tone;

  @override
  Widget build(BuildContext context) => Card(
    color: tone,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Đề xuất vào hàng chờ kiểm duyệt. Chuyên gia có thể sửa câu chữ trước khi công bố, '
              'tên bạn được ghi trong phần bản quyền của mục từ (FR-COMM-02/03).',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.contributionId, required this.onAnother});

  final String contributionId;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Đã nhận đề xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mã theo dõi: $contributionId\n'
              'Khi được duyệt, thuật ngữ xuất hiện trong kết quả tìm kiếm và mang tên bạn ở phần ghi công.',
              style: const TextStyle(fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAnother, child: const Text('Gửi đề xuất khác')),
            ),
          ],
        ),
      ),
    );
  }
}
