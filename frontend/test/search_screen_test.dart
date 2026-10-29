import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/search/search_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Trên máy thật lần mở đầu tiên phải seed 6.5k mục từ; người dùng hay gõ ngay
/// trong lúc đó. Test này giữ đúng tình huống ấy thay vì chỉ kiểm tra sau khi nạp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('search_screen_test');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('gõ trong lúc kho đang nạp vẫn ra kết quả sau khi nạp xong', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: SearchScreen(warmUp: () => gate.future)));

    await tester.enterText(find.byType(TextField), 'api');
    await tester.pump();
    expect(find.textContaining('Không có mục từ'), findsNothing,
        reason: 'kho chưa nạp xong thì chưa được kết luận là không tìm thấy');

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('API'), findsWidgets);
    expect(find.text('3 nguồn'), findsWidgets,
        reason: 'MDN, RFC và bản biên soạn phải được đếm chung một khái niệm');
  });
}
