import 'package:it_glossary/data/local/glossary_database.dart';

/// SQLite luôn được seed từ asset đóng gói (toàn bộ kho mục từ thật, issue #3),
/// nên một test kịch bản không thể giả định "chỉ có dữ liệu của mình": khái niệm
/// fixture sẽ đụng khái niệm thật và làm hỏng các so sánh về số nguồn, thứ hạng
/// kết quả. Dọn kho đóng gói trước khi nạp fixture để test tất định.
Future<void> clearPackagedCorpus() async {
  final db = await GlossaryDatabase.instance.database;
  await db.delete('local_term_relationships');
  await db.delete('term_aliases');
  await db.delete('terms');
}
