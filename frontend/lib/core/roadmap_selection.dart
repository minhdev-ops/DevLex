import 'package:flutter/foundation.dart';

/// Lựa chọn lộ trình nghề đang xem, chia sẻ giữa dashboard và tab Lộ trình.
class RoadmapSelection {
  RoadmapSelection._();

  static final ValueNotifier<String> instance = ValueNotifier<String>(
    'frontend',
  );
}
