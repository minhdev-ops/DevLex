import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:it_glossary/core/moderator_config.dart';
import 'package:it_glossary/data/api_client.dart';
import 'package:it_glossary/data/models/contribution.dart';
import 'package:it_glossary/features/moderation/moderation_screen.dart';

Map<String, dynamic> _row({
  String id = 'c_1',
  String status = 'pending',
  String acronym = 'gRPC',
}) => {
  'id': id,
  'status': status,
  'contributor_name': 'Trần Minh',
  'tier_1_acronym': acronym,
  'tier_1_full_name_en': 'gRPC Remote Procedure Call',
  'tier_1_short_definition': 'Framework RPC mã nguồn mở của Google.',
  'tier_2_detailed_explanation': null,
  'review_note': null,
  'created_at': '2026-10-30T09:00:00Z',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  tearDown(() => ModeratorConfig.instance.token.value = '');

  group('ApiClient — hàng chờ kiểm duyệt', () {
    test('gửi Bearer token + lọc theo status, parse đúng danh sách', () async {
      ModeratorConfig.instance.token.value = 'secret';
      http.Request? captured;

      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          captured = req;
          return _json({
            'status': 'success',
            'data': [_row()],
            'meta': {'count': 1, 'limit': 50, 'has_more': false},
          });
        }),
      );

      final result = await api.fetchContributions();

      expect(result.ok, isTrue);
      expect(result.items, hasLength(1));
      expect(result.items.first.acronym, 'gRPC');
      expect(result.items.first.contributorName, 'Trần Minh');
      expect(result.hasMore, isFalse);

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/api/v1/contributions');
      expect(captured!.url.queryParameters['status'], 'pending');
      expect(captured!.headers['Authorization'], 'Bearer secret');
    });

    test('thiếu token thì báo lỗi ngay, không gọi mạng', () async {
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          calls++;
          return _json({'data': []});
        }),
      );

      final result = await api.fetchContributions();

      expect(result.ok, isFalse);
      expect(result.error, contains('Chưa cấu hình token'));
      expect(calls, 0);
    });

    test('HTTP 401 → thông báo token không đúng', () async {
      ModeratorConfig.instance.token.value = 'wrong';
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async => _json({'message': 'Unauthorized'}, 401)),
      );

      final result = await api.fetchContributions();

      expect(result.ok, isFalse);
      expect(result.error, contains('Token kiểm duyệt không đúng'));
    });

    test('duyệt đề xuất gọi đúng endpoint', () async {
      ModeratorConfig.instance.token.value = 'secret';
      http.Request? captured;
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          captured = req;
          return _json({'message': 'Đã duyệt đề xuất.'});
        }),
      );

      final result = await api.approveContribution('c_9');

      expect(result.ok, isTrue);
      expect(result.message, 'Đã duyệt đề xuất.');
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/contributions/c_9/approve');
      expect(captured!.headers['Authorization'], 'Bearer secret');
    });

    test('từ chối gửi kèm review_note', () async {
      ModeratorConfig.instance.token.value = 'secret';
      http.Request? captured;
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          captured = req;
          return _json({'data': _row(status: 'rejected')});
        }),
      );

      final result = await api.rejectContribution('c_9', 'Trùng thuật ngữ đã có');

      expect(result.ok, isTrue);
      expect(captured!.url.path, '/api/v1/contributions/c_9/reject');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['review_note'], 'Trùng thuật ngữ đã có');
    });

    test('lỗi validate 422 trả về thông điệp đầu tiên từ server', () async {
      ModeratorConfig.instance.token.value = 'secret';
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient(
          (req) async => _json({
            'message': 'Dữ liệu không hợp lệ.',
            'errors': {
              'review_note': ['Cần ghi lý do.'],
            },
          }, 422),
        ),
      );

      final result = await api.rejectContribution('c_9', '');

      expect(result.ok, isFalse);
      expect(result.message, 'Cần ghi lý do.');
    });
  });

  group('Contribution model', () {
    test('parse payload snake_case và nhãn trạng thái tiếng Việt', () {
      final item = Contribution.fromJson(_row(status: 'rejected'));

      expect(item.id, 'c_1');
      expect(item.statusLabel, 'Từ chối');
      expect(item.isPending, isFalse);
      expect(item.createdAt, isNotNull);
    });
  });

  group('ModerationScreen', () {
    Future<void> pump(WidgetTester tester, http.Client client) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ModerationScreen(client: ApiClient(client: client))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('chưa có token thì hướng dẫn vào Cài đặt', (tester) async {
      await pump(tester, MockClient((req) async => _json({'data': []})));

      expect(find.text('Chưa cấu hình token kiểm duyệt'), findsOneWidget);
      expect(find.textContaining('Cài đặt'), findsWidgets);
    });

    testWidgets('duyệt xong thì thẻ biến khỏi hàng chờ', (tester) async {
      ModeratorConfig.instance.token.value = 'secret';
      var approved = 0;

      await pump(
        tester,
        MockClient((req) async {
          if (req.method == 'GET') {
            return _json({
              'status': 'success',
              'data': [_row()],
              'meta': {'has_more': false},
            });
          }
          approved++;
          return _json({'message': 'Đã duyệt đề xuất.'});
        }),
      );

      expect(find.text('gRPC'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
      await tester.pumpAndSettle();

      expect(approved, 1);
      expect(find.text('gRPC'), findsNothing);
      expect(find.text('Không còn đề xuất nào chờ duyệt'), findsOneWidget);
    });

    testWidgets('từ chối bắt buộc nhập lý do rồi mới gửi', (tester) async {
      ModeratorConfig.instance.token.value = 'secret';
      String? note;

      await pump(
        tester,
        MockClient((req) async {
          if (req.method == 'GET') {
            return _json({
              'status': 'success',
              'data': [_row()],
              'meta': {'has_more': false},
            });
          }
          note = (jsonDecode(req.body) as Map<String, dynamic>)['review_note']
              as String?;
          return _json({'data': _row(status: 'rejected')});
        }),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pump();
      expect(find.textContaining('Cần ghi lý do'), findsOneWidget);
      expect(note, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Lý do từ chối'),
        'Trùng thuật ngữ đã có',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();

      expect(note, 'Trùng thuật ngữ đã có');
      expect(find.text('gRPC'), findsNothing);
    });

    testWidgets('lỗi máy chủ hiện thẻ thử lại', (tester) async {
      ModeratorConfig.instance.token.value = 'secret';

      await pump(
        tester,
        MockClient((req) async => _json({'message': 'boom'}, 500)),
      );

      expect(find.text('Không tải được hàng chờ'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Thử lại'), findsOneWidget);
    });
  });
}
