import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/features/contribute/contribution_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, http.Client client) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ContributionScreen(api: ApiClient(client: client)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('form trống bị chặn: không gọi API, hiện lỗi validation', (tester) async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response('{}', 201);
    });

    await pumpScreen(tester, client);
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('Không được để trống.'), findsWidgets);
  });

  testWidgets('form hợp lệ gửi đúng endpoint + body snake_case', (tester) async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'message': 'Đã ghi nhận đề xuất.'}),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await pumpScreen(tester, client);

    Future<void> fill(String label, String value) async =>
        tester.enterText(find.widgetWithText(TextFormField, label).last, value);

    await tester.pump();
    await fill('Tên người đóng góp', 'Trần Minh');
    await fill('Từ viết tắt (Tầng 1)', 'gRPC');
    await fill('Tên đầy đủ tiếng Anh', 'gRPC Remote Procedure Call');
    await fill('Định nghĩa ngắn (Tầng 1)', 'Framework RPC mã nguồn mở.');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pumpAndSettle(); // flush async network

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/api/v1/contributions');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['contributor_name'], 'Trần Minh');
    expect(body['tier_1_acronym'], 'gRPC');
    expect(find.byType(SnackBar), findsOneWidget);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect((snack.content as Text).data, 'Đã ghi nhận đề xuất.');
  });

  testWidgets('mất mạng: báo lỗi, không crash', (tester) async {
    final client = MockClient((req) async => throw Exception('offline'));

    await pumpScreen(tester, client);
    Future<void> fill(String label, String value) async =>
        tester.enterText(find.widgetWithText(TextFormField, label).last, value);

    await tester.pump();
    await fill('Tên người đóng góp', 'Minh');
    await fill('Từ viết tắt (Tầng 1)', 'API');
    await fill('Tên đầy đủ tiếng Anh', 'Application Programming Interface');
    await fill('Định nghĩa ngắn (Tầng 1)', 'Quy tắc giao tiếp.');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi đề xuất'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
  });
}
