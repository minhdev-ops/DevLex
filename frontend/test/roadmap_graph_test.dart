import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_glossary/data/glossary_repository.dart';
import 'package:it_glossary/data/models/term.dart';
import 'package:it_glossary/features/roadmap/roadmap_screen.dart';

/// FR-MAP-02: chọn một nút trên sơ đồ phải làm nổi bật nhánh tiên quyết/kế tiếp
/// và cho phép đi dọc nhánh đó mà không rời sơ đồ.
Term _term(String id, String acronym, {List<String> prerequisites = const []}) => Term(
      id: id,
      acronym: acronym,
      fullNameEn: '$acronym full name',
      fullNameVi: '',
      shortDefinition: 'Định nghĩa $acronym dùng cho kiểm thử sơ đồ.',
      detailedExplanation: '',
      metaphorAnalogy: '',
      diagramUrl: '',
      categoryTags: const [],
      difficulty: 'Beginner',
      prerequisites: prerequisites,
      relatedTerms: const [],
      career: 'backend',
      attribution: const [],
    );

void main() {
  // json <- api <- spa/rest, cộng một nút cô lập để thấy hiệu ứng làm mờ
  final terms = <Term>[
    _term('json', 'JSON'),
    _term('api', 'API', prerequisites: ['json']),
    _term('spa', 'SPA', prerequisites: ['api']),
    _term('rest', 'REST', prerequisites: ['api']),
    _term('orb', 'ORB'),
  ];

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeGraphView(terms: terms, repo: GlossaryRepository.instance, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double opacityOf(WidgetTester tester, String acronym) {
    final found = find.ancestor(
      of: find.text(acronym),
      matching: find.byWidgetPredicate((w) => w is Opacity),
    );
    return found.evaluate().isEmpty
        ? 1.0
        : (tester.widget<Opacity>(found.first)).opacity;
  }

  testWidgets('chưa chọn nút nào thì mọi nút đều hiển thị đầy đủ', (tester) async {
    await mount(tester);
    for (final a in ['JSON', 'API', 'SPA', 'REST', 'ORB']) {
      expect(find.text(a), findsOneWidget);
      expect(opacityOf(tester, a), 1.0);
    }
  });

  testWidgets('chạm nút: card nhanh + làm mờ nhánh không liên quan', (tester) async {
    await mount(tester);

    await tester.tap(find.text('API'));
    await tester.pumpAndSettle();

    expect(find.text('Cần biết trước'), findsOneWidget);
    expect(find.text('Mở khóa cho'), findsOneWidget);
    expect(find.text('Định nghĩa API dùng cho kiểm thử sơ đồ.'), findsOneWidget);

    expect(opacityOf(tester, 'ORB'), lessThan(1.0), reason: 'nút ngoài nhánh phải mờ đi');
    expect(opacityOf(tester, 'JSON'), 1.0, reason: 'tiên quyết nằm trong nhánh');
    expect(opacityOf(tester, 'SPA'), 1.0);
  });

  testWidgets('chạm chip tiên quyết chuyển trọng tâm ngay trên sơ đồ', (tester) async {
    await mount(tester);

    await tester.tap(find.text('API'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'JSON'));
    await tester.pumpAndSettle();

    // card giờ là của JSON nên không còn mục "Cần biết trước", chỉ còn "Mở khóa cho"
    expect(find.text('Cần biết trước'), findsNothing);
    expect(find.text('Mở khóa cho'), findsOneWidget);
    expect(find.text('Định nghĩa JSON dùng cho kiểm thử sơ đồ.'), findsOneWidget);
    expect(find.text('Bỏ nhánh của JSON'), findsOneWidget, reason: 'trọng tâm đổi theo chip vừa chạm');
  });

  testWidgets('nút "Bỏ nhánh" xóa highlight', (tester) async {
    await mount(tester);

    await tester.tap(find.text('API'));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 'ORB'), lessThan(1.0));

    await tester.tapAt(const Offset(10, 10)); // barrier đóng card, không đụng nút nào
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bỏ nhánh của API'));
    await tester.pumpAndSettle();

    expect(find.text('Bỏ nhánh của API'), findsNothing);
    expect(opacityOf(tester, 'ORB'), 1.0, reason: 'toàn bộ sơ đồ trở lại mức hiển thị đầy đủ');
  });
}
