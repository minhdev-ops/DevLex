import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_config.dart';

/// Trạng thái kết nối tới backend (thứ duy nhất app cần mạng để làm).
///
/// App offline-first: mạng chỉ dùng để đồng bộ / gửi đóng góp. Vì vậy "online"
/// ở đây nghĩa là *backend có tới được hay không*, chứ không phải "máy có
/// Internet chung" — nên ta mở thử một kết nối TCP tới host:port của API.
/// Nhờ vậy khi backend chạy local (kể cả qua `adb reverse`) badge vẫn báo Online
/// đúng, và khi mất mạng / backend tắt thì báo Offline để dùng bản trong máy.
class ConnectivityStatus {
  ConnectivityStatus._();

  static final ConnectivityStatus instance = ConnectivityStatus._();

  /// true = backend đang tới được. Mặc định true để không báo offline oan.
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  /// Thử mở TCP tới API. Fail-safe: mọi lỗi đều coi như offline để UI an toàn.
  Future<bool> checkNow() async {
    try {
      final uri = Uri.parse(ApiConfig.instance.baseUrl.value);
      final host = uri.host;
      final port = uri.hasPort
          ? uri.port
          : (uri.scheme == 'https' ? 443 : 80);
      if (host.isEmpty) {
        online.value = false;
        return false;
      }
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      online.value = true;
      return true;
    } catch (_) {
      online.value = false;
      return false;
    }
  }
}
