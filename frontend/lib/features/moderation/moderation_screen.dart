import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/moderator_config.dart';
import '../../data/api_client.dart';
import '../../data/models/contribution.dart';

/// FR-COMM-02: hàng chờ kiểm duyệt đóng góp cộng đồng.
///
/// Chỉ hoạt động khi đã nhập token moderator trong Cài đặt — backend không trả
/// danh sách khi thiếu token vì hàng chờ chứa tên người gửi (PII).
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key, this.client});

  /// Cho phép bơm client giả trong test.
  final ApiClient? client;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  late final ApiClient _api = widget.client ?? ApiClient();

  String _status = Contribution.statusPending;
  bool _loading = false;
  String? _error;
  List<Contribution> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    if (!ModeratorConfig.instance.isConfigured) {
      setState(() {
        _loading = false;
        _error = null;
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchContributions(status: _status);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error;
      _items = result.items;
    });
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _items = const [];
    });
    _load();
  }

  Future<void> _approve(Contribution item) async {
    final result = await _api.approveContribution(item.id);
    if (!mounted) return;
    _afterReview(item, result);
  }

  Future<void> _reject(Contribution item) async {
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RejectDialog(acronym: item.acronym),
    );
    if (note == null || !mounted) return;
    final result = await _api.rejectContribution(item.id, note);
    if (!mounted) return;
    _afterReview(item, result);
  }

  void _afterReview(Contribution item, ModerationResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (!result.ok) return;
    setState(() {
      _items = _items.where((row) => row.id != item.id).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hàng chờ kiểm duyệt'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: ModeratorConfig.instance.token,
        builder: (context, token, _) {
          if (token.isEmpty) return const _MissingTokenCard();
          return Column(
            children: [
              _StatusFilter(selected: _status, onSelected: _selectStatus),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Không tải được hàng chờ',
        message: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return _MessageCard(
        icon: Icons.inbox_outlined,
        title: _status == Contribution.statusPending
            ? 'Không còn đề xuất nào chờ duyệt'
            : 'Chưa có đề xuất ở trạng thái này',
        message: 'Kéo xuống hoặc bấm tải lại để kiểm tra máy chủ.',
        actionLabel: 'Tải lại',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _items[index];
          return _ContributionCard(
            item: item,
            onApprove: item.isPending ? () => _approve(item) : null,
            onReject: item.isPending ? () => _reject(item) : null,
          );
        },
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (final entry in const {
            Contribution.statusPending: 'Chờ duyệt',
            Contribution.statusApproved: 'Đã duyệt',
            Contribution.statusRejected: 'Từ chối',
          }.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final Contribution item;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.acronym.isEmpty ? '(chưa có acronym)' : item.acronym,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                _StatusBadge(status: item.status, label: item.statusLabel),
              ],
            ),
            if (item.fullNameEn.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.fullNameEn,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.shortDefinition,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Ghi chú: ${item.reviewNote}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.contributorName.isEmpty
                        ? 'Ẩn danh'
                        : item.contributorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (item.createdAt != null)
                  Text(
                    _date(item.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Duyệt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Từ chối'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      Contribution.statusApproved => scheme.primaryContainer,
      Contribution.statusRejected => scheme.errorContainer,
      _ => scheme.surfaceContainerHighest,
    };
    final foreground = switch (status) {
      Contribution.statusApproved => scheme.onPrimaryContainer,
      Contribution.statusRejected => scheme.onErrorContainer,
      _ => scheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissingTokenCard extends StatelessWidget {
  const _MissingTokenCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.lock_outline,
      title: 'Chưa cấu hình token kiểm duyệt',
      message:
          'Vào tab Cài đặt → mục “Kiểm duyệt đóng góp” để nhập token moderator '
          'do quản trị viên cấp. Hàng chờ chỉ mở khi có token hợp lệ.',
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.acronym});

  final String acronym;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _controller.text.trim();
    if (note.isEmpty) {
      setState(() => _error = 'Cần ghi lý do để người gửi biết cần sửa gì.');
      return;
    }
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Từ chối “${widget.acronym}”?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 2000,
        decoration: InputDecoration(
          labelText: 'Lý do từ chối',
          hintText: 'Ví dụ: định nghĩa trùng thuật ngữ đã có',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Từ chối')),
      ],
    );
  }
}
