import 'package:flutter/material.dart';

import '../../core/contribution_draft.dart';
import '../../data/api_client.dart';

/// FR-COMM-01: biểu mẫu gửi đề xuất thuật ngữ mới / bản dịch vào hàng chờ kiểm duyệt.
class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, this.api});

  final ApiClient? api;

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
  bool _submitting = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final res = await _api.submitContribution(_draft().toJson());
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.ok ? Theme.of(context).colorScheme.primary : Colors.red.shade700,
      ),
    );
    if (res.ok) {
      _formKey.currentState!.reset();
      for (final c in [_acronym, _fullName, _shortDef, _detail]) {
        c.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đóng góp thuật ngữ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Đề xuất của bạn sẽ vào hàng chờ kiểm duyệt bởi chuyên gia kỹ thuật (FR-COMM-02) '
              'trước khi được ghi nhận và hiển thị tên bạn trong phần bản quyền (FR-COMM-03).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên người đóng góp', border: OutlineInputBorder()),
              validator: (v) => v != null && v.trim().length >= 2 ? null : 'Tối thiểu 2 ký tự.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _acronym,
              decoration: const InputDecoration(labelText: 'Từ viết tắt (Tầng 1)', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Tên đầy đủ tiếng Anh', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortDef,
              maxLines: 3,
              maxLength: ContributionDraft.maxShort,
              decoration: const InputDecoration(
                  labelText: 'Định nghĩa ngắn (Tầng 1)', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống.' : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _detail,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Giải thích chi tiết (Tầng 2, không bắt buộc)',
                  border: OutlineInputBorder()),
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
