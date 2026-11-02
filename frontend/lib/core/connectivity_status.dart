import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Trạng thái kết nối mạng chung (không phải độ khả dụng của một API cụ thể).
///
/// App offline-first: mạng chỉ dùng để đồng bộ / gửi đóng góp. Do đó chỉ cần
/// biết "có mạng hay không" để hiển thị badge, không cần ping đích cụ thể.
///
/// Dò qua DNS public (không phụ thuộc host API) nên vẫn đúng ngay cả khi máy
/// chủ glossary tạm offline mà thiết bị vẫn có mạng.
class ConnectivityStatus {
  ConnectivityStatus._();

  static final ConnectivityStatus instance = ConnectivityStatus._();

  /// true = thiết bị đang có mạng. Mặc định true để không báo offline oan.
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  static const String _probeHost = 'dns.google';

  /// Thử dò kết nối. Fail-safe: bất kỳ lỗi nào cũng coi như offline để UI an toàn.
  Future<bool> checkNow() async {
    try {
      final result = await InternetAddress.lookup(_probeHost)
          .timeout(const Duration(seconds: 3));
      final ok = result.isNotEmpty &&
          result.any((a) => a.rawAddress.isNotEmpty);
      online.value = ok;
      return ok;
    } on SocketException {
      online.value = false;
      return false;
    } catch (_) {
      online.value = false;
      return false;
    }
  }
}
