import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/app_theme.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/decoder/decoder_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chữ được highlight trong ví dụ mẫu phải đọc được ở cả nền sáng và nền tối.
/// Trước đây màu chữ được chốt lúc phân tích văn bản nên khi bật giao diện tối
/// chữ gần như biến mất trên nền tối.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('decodercontrastOf');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  double luminanceOf(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrastOf(Color a, Color b) {
    final la = luminanceOf(a);
    final lb = luminanceOf(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  Future<List<TextSpan>> highlightedSpans(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const DecoderScreen()),
    );
    await tester.pumpAndSettle();

    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (w) =>
              w.text is TextSpan &&
              ((w.text as TextSpan).children?.length ?? 0) == 1 &&
              w.text.toPlainText().contains('REST'),
        );
    // Text.rich bọc span của mình trong một TextSpan gốc -> đi xuống một tầng.
    final root = (rich.text as TextSpan).children!.first as TextSpan;
    return [
      for (final child in root.children ?? const <InlineSpan>[])
        if (child is TextSpan && child.style?.backgroundColor != null) child,
    ];
  }

  testWidgets('highlight đọc được ở nền sáng', (tester) async {
    final spans = await highlightedSpans(tester, AppTheme.light());
    expect(spans, isNotEmpty, reason: 'ví dụ mẫu phải có thuật ngữ được highlight');
    for (final s in spans) {
      expect(
        contrastOf(s.style!.color!, s.style!.backgroundColor!),
        greaterThan(4.5),
        reason: 'chữ "${s.text}" quá mờ trên nền highlight',
      );
    }
  });

  testWidgets('highlight đọc được ở nền tối', (tester) async {
    final spans = await highlightedSpans(tester, AppTheme.dark());
    expect(spans, isNotEmpty);
    for (final s in spans) {
      expect(
        contrastOf(s.style!.color!, s.style!.backgroundColor!),
        greaterThan(4.5),
        reason: 'chữ "${s.text}" quá mờ trên nền highlight',
      );
    }
  });
}
