import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/features/contribute/contribution_screen.dart';

/// Bộ nhớ tên thay thế SQLite để kiểm thử biểu mẫu mà không cần DB.
class _MemoryStore extends ContributorNameStore {
  _MemoryStore([this.saved]);

  String? saved;
  String? written;

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> write(String name) async => written = name;
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, http.Client client, {ContributorNameStore? store}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ContributionScreen(
          api: ApiClient(client: client),
          nameStore: store ?? _MemoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async =>
      tester.enterText(find.widgetWithText(TextFormField, label).last, value);

  Future<void> fillValidForm(WidgetTester tester) async {
    await fill(tester, 'Tên người đóng góp', 'Trần Minh');
    await fill(tester, 'Từ viết tắt (Tầng 1)', 'gRPC');
    await fill(tester, 'Tên đầy đủ tiếng Anh', 'gRPC Remote Procedure Call');
    await fill(tester, 'Định nghĩa ngắn (Tầng 1)', 'Framework RPC mã nguồn mở.');
    await tester.pump();
  }

  testWidgets('form trống bị chặn: không gọi API, hiện lỗi validation', (tester) async {
    var calls = 0;
    await pumpScreen(
      tester,
      MockClient((req) async {
        calls++;
        return http.Response('{}', 201);
      }),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pump();

    expect(calls, 0);
    expect(find.textContaining('không được để trống'), findsWidgets);
    expect(find.textContaining('tối thiểu 2 ký tự'), findsOneWidget);
  });

  testWidgets('form hợp lệ gửi đúng endpoint + body snake_case', (tester) async {
    http.Request? captured;
    await pumpScreen(
      tester,
      MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'message': 'Đã ghi nhận đề xuất.'}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/api/v1/contributions');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['contributor_name'], 'Trần Minh');
    expect(body['tier_1_acronym'], 'gRPC');
  });

  testWidgets('gửi thành công: hiện mã theo dõi, xóa nội dung, giữ tên', (tester) async {
    final store = _MemoryStore();
    await pumpScreen(
      tester,
      MockClient((req) async {
        return http.Response(
          jsonEncode({
            'message': 'ok',
            'data': {'id': 'c_deadbeef'},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
      store: store,
    );

    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Đã nhận đề xuất'), findsOneWidget);
    expect(find.textContaining('c_deadbeef'), findsOneWidget);
    expect(store.written, 'Trần Minh', reason: 'FR-COMM-03: tên contributor phải được lưu lại');

    final acronymField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Từ viết tắt (Tầng 1)').last);
    expect(acronymField.controller!.text, isEmpty, reason: 'nội dung vừa gửi phải được dọn sạch');

    await tester.tap(find.text('Gửi đề xuất khác'));
    await tester.pumpAndSettle();
    expect(find.text('Đã nhận đề xuất'), findsNothing);
  });

  testWidgets('tên đã lưu được điền sẵn cho lần sau', (tester) async {
    await pumpScreen(tester, MockClient((req) async => http.Response('{}', 201)), store: _MemoryStore('Nguyen Van A'));

    expect(find.text('Nguyen Van A'), findsOneWidget);
  });

  testWidgets('mất mạng: báo lỗi, không chuyển sang trạng thái đã gửi', (tester) async {
    final store = _MemoryStore();
    await pumpScreen(tester, MockClient((req) async => throw Exception('offline')), store: store);

    await fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    expect(find.text('Đã nhận đề xuất'), findsNothing);
    expect(store.written, isNull);
  });
}
