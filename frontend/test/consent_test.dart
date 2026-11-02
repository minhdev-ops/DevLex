import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/consent.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/legal/consent_sheet.dart';
import 'package:it_glossary/features/legal/privacy_policy_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('consent_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  test('mặc định chưa đồng ý, đồng ý xong lưu được và đọc lại được', () async {
    await Consent.instance.reset();
    await Consent.instance.load();
    expect(Consent.instance.accepted.value, isFalse);

    await Consent.instance.accept();
    expect(Consent.instance.accepted.value, isTrue);
    expect(
      await GlossaryDatabase.instance.getMeta(Consent.metaKey),
      'true',
    );

    await Consent.instance.reset();
    expect(Consent.instance.accepted.value, isFalse);
  });

  test('load() gọi song song dùng chung một lần đọc', () async {
    // main() và HomeShell cùng gọi load(): nếu mỗi lần trả về một Future mới,
    // bên gọi sau thấy accepted == false lúc DB còn đang mở và hỏi lại người
    // dùng ở mọi cold start.
    final first = Consent.instance.load();
    final second = Consent.instance.load();

    expect(identical(first, second), isTrue);
    await first;
  });

  testWidgets('chính sách hiển thị đủ các mục bắt buộc', (tester) async {
    // ListView chỉ dựng các mục trong khung nhìn: dùng màn cao để thấy hết.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Chính sách quyền riêng tư'), findsOneWidget);
    expect(find.textContaining('Dữ liệu lưu trên thiết bị'), findsOneWidget);
    expect(find.textContaining('Khi nào dữ liệu rời thiết bị'), findsOneWidget);
    expect(find.textContaining('Dữ liệu chúng tôi không thu thập'), findsOneWidget);
    expect(find.textContaining('Quyền ứng dụng'), findsOneWidget);
    expect(find.textContaining('Xóa dữ liệu của bạn'), findsOneWidget);
  });

  testWidgets('banner lần đầu mở app mở được chính sách đầy đủ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showConsentSheet(context),
                child: const Text('mở banner'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở banner'));
    await tester.pumpAndSettle();

    expect(find.text('Trước khi bắt đầu'), findsOneWidget);
    expect(find.text('Đã hiểu và đồng ý'), findsOneWidget);
    expect(find.textContaining('Không quảng cáo'), findsNothing);

    await tester.tap(find.text('Đọc chính sách đầy đủ'));
    await tester.pumpAndSettle();

    expect(find.text('Chính sách quyền riêng tư'), findsWidgets);
  });
}
