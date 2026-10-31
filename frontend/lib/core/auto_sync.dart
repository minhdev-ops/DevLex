import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/glossary_repository.dart';

/// Tự đồng bộ delta khi app quay lại foreground.
///
/// Trước đây người dùng phải bấm "Đồng bộ ngay" trong Cài đặt. Bộ điều khiển này
/// chỉ gọi mạng khi dữ liệu đã cũ ([maxAge]) để không tốn pin/dữ liệu mỗi lần
/// mở app, và bỏ qua hoàn toàn khi đang có một lần đồng bộ chạy dở.
///
/// Lưu ý: đây là đồng bộ theo vòng đời app, không phải job nền của hệ điều hành —
/// muốn chạy cả khi app đã bị đóng cần thêm WorkManager.
class AutoSync with WidgetsBindingObserver {
  AutoSync({this.maxAge = const Duration(hours: 6)});

  /// Khoảng cách tối thiểu giữa hai lần tự đồng bộ.
  final Duration maxAge;

  /// Kết quả lần tự đồng bộ gần nhất, để UI hiển thị nếu muốn.
  final ValueNotifier<SyncOutcome?> lastOutcome = ValueNotifier<SyncOutcome?>(
    null,
  );

  bool _running = false;

  bool get running => _running;

  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(maybeSync());
    }
  }

  /// Đồng bộ nếu dữ liệu đã cũ (hoặc [force] = true).
  ///
  /// Trả về null khi bỏ qua vì dữ liệu còn mới / đang đồng bộ / lỗi mạng được
  /// xử lý im lặng — app offline-first không được làm phiền người dùng.
  Future<SyncOutcome?> maybeSync({
    bool force = false,
    GlossaryRepository? repository,
    ApiClient? api,
  }) async {
    if (_running) return null;
    _running = true;
    try {
      final repo = repository ?? GlossaryRepository.instance;
      if (!force) {
        final last = await repo.lastSyncAt();
        if (last != null && DateTime.now().difference(last) < maxAge) {
          return null;
        }
      }
      final outcome = await repo.syncNow(api: api);
      lastOutcome.value = outcome;
      return outcome;
    } catch (_) {
      // Lỗi bất ngờ (DB chưa mở, JSON hỏng...) không được làm sập app.
      return null;
    } finally {
      _running = false;
    }
  }
}
