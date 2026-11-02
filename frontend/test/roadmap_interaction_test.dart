import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/core/app_theme.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/local/glossary_database.dart';
import 'package:it_glossary/features/roadmap/roadmap_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sơ đồ tư duy phải kéo và thu phóng được trên màn điện thoại: canvas lớn
/// hơn khung nhìn nên người dùng cần di chuyển, và cần nút phóng to cho người
/// không quen chụm hai ngón.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('roadmap_interaction');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseFactoryFfi.setDatabasesPath(dir.path);
    await GlossaryRepository.instance.warmUp();
  });

  tearDownAll(() async {
    await GlossaryDatabase.instance.close();
    dir.deleteSync(recursive: true);
  });

  Future<TransformationController> pumpGraph(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = GlossaryRepository.instance;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: KnowledgeGraphView(
            terms: repo.termsByCareer('frontend'),
            repo: repo,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    return viewer.transformationController!;
  }

  testWidgets('tự canh vừa màn hình khi mở', (tester) async {
    final view = await pumpGraph(tester);

    expect(
      view.value.getMaxScaleOnAxis(),
      lessThanOrEqualTo(1.0),
      reason: 'canvas 1488px không được vẽ tràn ra ngoài khung 360px',
    );
    expect(
      view.value.getMaxScaleOnAxis(),
      greaterThanOrEqualTo(0.35),
    );
  });

  testWidgets('kéo một ngón để di chuyển sơ đồ', (tester) async {
    final view = await pumpGraph(tester);
    final before = view.value.getTranslation();

    await tester.drag(find.byType(InteractiveViewer), const Offset(-90, -70));
    await tester.pumpAndSettle();

    final after = view.value.getTranslation();
    expect(
      (after - before).length,
      greaterThan(30),
      reason: 'kéo phải đổi vị trí canvas, không được đứng yên',
    );
  });

  testWidgets('nút phóng to / thu nhỏ đổi tỉ lệ', (tester) async {
    final view = await pumpGraph(tester);
    final start = view.value.getMaxScaleOnAxis();

    await tester.tap(find.byTooltip('Phóng to'));
    await tester.pumpAndSettle();
    final zoomed = view.value.getMaxScaleOnAxis();
    expect(zoomed, greaterThan(start));

    await tester.tap(find.byTooltip('Thu nhỏ'));
    await tester.pumpAndSettle();
    expect(view.value.getMaxScaleOnAxis(), lessThan(zoomed));
  });

  testWidgets('nút vừa màn hình đưa tỉ lệ về mức canh toàn sơ đồ', (tester) async {
    final view = await pumpGraph(tester);
    final fitted = view.value.getMaxScaleOnAxis();

    await tester.tap(find.byTooltip('Phóng to'));
    await tester.pumpAndSettle();
    expect(view.value.getMaxScaleOnAxis(), greaterThan(fitted));

    await tester.tap(find.byTooltip('Vừa màn hình'));
    await tester.pumpAndSettle();
    expect(
      view.value.getMaxScaleOnAxis(),
      closeTo(fitted, 0.01),
    );
  });
}
