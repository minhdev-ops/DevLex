// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';

import '../core/connectivity_status.dart';
import '../data/glossary_repository.dart';

/// Viên trạng thái đồng bộ: rõ ràng online/offline + nút đồng bộ một chạm.
///
/// Nằm ngay trên tab Tra cứu (trang chủ) nên người dùng luôn thấy app vừa hoạt
/// động offline, vừa có thể kéo bản mới khi online — điểm khác biệt chính.
class SyncStatusPill extends StatefulWidget {
  const SyncStatusPill({
    super.key,
    required this.onSync,
    this.syncing = false,
  });

  /// Hàm đồng bộ của màn chủ gọi khi người dùng chạm vào viên.
  final Future<void> Function() onSync;

  final bool syncing;

  @override
  State<SyncStatusPill> createState() => _SyncStatusPillState();
}

class _SyncStatusPillState extends State<SyncStatusPill> {
  DateTime? _lastSync;
  final _repo = GlossaryRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
    ConnectivityStatus.instance.online.addListener(_onChanged);
    // Đồng bộ chạy ngầm (auto-sync / nút Đồng bộ) xong sẽ bump progressRevision:
    // nghe để viên cập nhật "đã đồng bộ X trước" ngay, không bị kẹt ở trạng thái cũ.
    _repo.progressRevision.addListener(_onSyncTick);
  }

  @override
  void dispose() {
    ConnectivityStatus.instance.online.removeListener(_onChanged);
    _repo.progressRevision.removeListener(_onSyncTick);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onSyncTick() => _load();

  Future<void> _load() async {
    final at = await _repo.lastSyncAt();
    if (mounted) setState(() => _lastSync = at);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = ConnectivityStatus.instance.online.value;
    final synced = _lastSync != null;

    final Color dot = online ? scheme.primary : scheme.outline;
    final String label;
    if (widget.syncing) {
      label = 'Đang đồng bộ…';
    } else if (online) {
      label = synced
          ? 'Online · đã đồng bộ ' + _ago(_lastSync!)
          : 'Online · chạm để đồng bộ';
    } else {
      label = synced
          ? 'Offline · bản trong máy ' + _ago(_lastSync!)
          : 'Offline · dùng bản trong máy';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: widget.syncing
          ? null
          : () async {
              await widget.onSync();
              await ConnectivityStatus.instance.checkNow();
              await _load();
              if (mounted) setState(() {});
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: online
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.syncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.circle, size: 9, color: dot),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inHours < 1) return d.inMinutes.toString() + ' phút trước';
    if (d.inDays < 1) return d.inHours.toString() + ' giờ trước';
    if (d.inDays < 30) return d.inDays.toString() + ' ngày trước';
    return at.toLocal().toString().split(' ').first;
  }
}
