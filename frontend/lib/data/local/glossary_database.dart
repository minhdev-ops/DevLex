import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/term.dart';

/// SQLite offline-first: DB được seed sẵn từ asset (chiến lược pre-packaged DB,
/// SRS mục 5). Mảng được JSON-serialize thành TEXT; bảng liên kết cục bộ có INDEX.
class GlossaryDatabase {
  GlossaryDatabase._();

  static final GlossaryDatabase instance = GlossaryDatabase._();

  static const _dbName = 'glossary.db';
  static const _dbVersion = 4;
  static const _seedAsset = 'assets/seed/terms.json';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  /// Đóng và quên kết nối — test cần mở lại một DB tạm khác.
  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE terms(
            id TEXT PRIMARY KEY,
            acronym TEXT NOT NULL,
            full_name_en TEXT NOT NULL,
            full_name_vi TEXT NOT NULL,
            short_definition TEXT NOT NULL,
            detailed_explanation TEXT,
            metaphor_analogy TEXT,
            diagram_url TEXT,
            category_tags TEXT NOT NULL DEFAULT '[]',
            difficulty TEXT NOT NULL DEFAULT 'Beginner',
            prerequisites TEXT NOT NULL DEFAULT '[]',
            related_terms TEXT NOT NULL DEFAULT '[]',
            career TEXT,
            concept TEXT,
            source_attribution TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute('CREATE INDEX idx_terms_acronym ON terms(acronym)');
        await db.execute('CREATE INDEX idx_terms_full_name_en ON terms(full_name_en)');
        await db.execute('''
          CREATE TABLE term_aliases(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            term_id TEXT NOT NULL,
            alias TEXT NOT NULL UNIQUE,
            naming_rule_note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE local_term_relationships(
            parent_id TEXT NOT NULL,
            child_id TEXT NOT NULL,
            relation_type TEXT NOT NULL,
            PRIMARY KEY(parent_id, child_id, relation_type)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_relationships_parent ON local_term_relationships(parent_id)');
        await db.execute(
            'CREATE INDEX idx_relationships_child ON local_term_relationships(child_id)');
        await db.execute('''
          CREATE TABLE study_state(
            term_id TEXT PRIMARY KEY,
            status TEXT NOT NULL DEFAULT 'new',
            interval_days INTEGER NOT NULL DEFAULT 0,
            due_date TEXT,
            last_review TEXT,
            streak INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_meta(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _seedFromAsset(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE study_state(
              term_id TEXT PRIMARY KEY,
              status TEXT NOT NULL DEFAULT 'new',
              interval_days INTEGER NOT NULL DEFAULT 0,
              due_date TEXT,
              last_review TEXT,
              streak INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE sync_meta(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE terms ADD COLUMN concept TEXT');
        }
      },
    );
    return db;
  }

  Future<void> _seedFromAsset(Database db) async {
    final raw = await rootBundle.loadString(_seedAsset);
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final terms = (data['terms'] as List<dynamic>)
        .map((e) => Term.fromJson(e as Map<String, dynamic>))
        .toList();

    final batch = db.batch();
    for (final t in terms) {
      batch.insert('terms', {
        'id': t.id,
        'acronym': t.acronym,
        'full_name_en': t.fullNameEn,
        'full_name_vi': t.fullNameVi,
        'short_definition': t.shortDefinition,
        'detailed_explanation': t.detailedExplanation,
        'metaphor_analogy': t.metaphorAnalogy,
        'diagram_url': t.diagramUrl,
        'category_tags': jsonEncode(t.categoryTags),
        'difficulty': t.difficulty,
        'prerequisites': jsonEncode(t.prerequisites),
        'related_terms': jsonEncode(t.relatedTerms),
        'career': t.career,
        'concept': t.concept,
        'source_attribution': jsonEncode(
            t.attribution.map((a) => a.toJson()).toList()),
      });
      for (final p in t.prerequisites) {
        batch.insert('local_term_relationships',
            {'parent_id': p, 'child_id': t.id, 'relation_type': 'prerequisite'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final r in t.relatedTerms) {
        batch.insert('local_term_relationships',
            {'parent_id': t.id, 'child_id': r, 'relation_type': 'related'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    for (final a in (data['aliases'] as List<dynamic>? ?? [])) {
      final alias = a as Map<String, dynamic>;
      batch.insert('term_aliases', {
        'term_id': alias['termId'],
        'alias': alias['alias'],
        'naming_rule_note': alias['namingRuleNote'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Term>> loadAllTerms() async {
    final db = await database;
    final rows = await db.query('terms');
    return rows.map(_termFromRow).toList();
  }

  Future<Map<String, TermAlias>> loadAliases() async {
    final db = await database;
    final rows = await db.query('term_aliases');
    return {
      for (final r in rows)
        (r['alias'] as String).toLowerCase(): TermAlias(
          termId: r['term_id'] as String,
          alias: r['alias'] as String,
          namingRuleNote: r['naming_rule_note'] as String?,
        ),
    };
  }

  Future<StudyState> getStudyState(String termId) async {
    final db = await database;
    final row = await db.query('study_state', where: 'term_id = ?', whereArgs: [termId], limit: 1);
    if (row.isEmpty) return StudyState.empty;
    return StudyState.fromRow(row.first);
  }

  Future<void> saveStudyState({
    required String termId,
    required bool learned,
    int intervalDays = 0,
    String? dueDate,
    int streak = 0,
  }) async {
    final db = await database;
    await db.insert('study_state', {
      'term_id': termId,
      'status': learned ? 'learned' : 'needs_review',
      'interval_days': intervalDays,
      'due_date': dueDate,
      'last_review': DateTime.now().toUtc().toIso8601String(),
      'streak': streak,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, StudyState>> allStudyStates() async {
    final db = await database;
    final rows = await db.query('study_state');
    return {
      for (final r in rows) r['term_id'] as String: StudyState.fromRow(r),
    };
  }

  /// Tỷ lệ % học viên đã hoàn thành trên một lộ trình nghề nghiệp (FR-MAP-03).
  Future<int> progressPercent(String career) async {
    final db = await database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM terms WHERE career = ?', [career])) ?? 0;
    if (total == 0) return 0;
    final done = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM study_state s JOIN terms t ON t.id = s.term_id '
        'WHERE t.career = ? AND s.status = \'learned\'', [career])) ?? 0;
    return (done * 100 / total).round();
  }

  /// Số thuật ngữ người dùng đã xem/đánh dấu (điều kiện tối thiểu cho Quiz FR-QUIZ-01).
  Future<List<Term>> termsWithStudyState() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT t.* FROM terms t JOIN study_state s ON t.id = s.term_id');
    return rows.map(_termFromRow).toList();
  }

  Term _termFromRow(Map<String, Object?> row) {
    List<String> decodeStringList(Object? value) =>
        (jsonDecode((value as String?) ?? '[]') as List<dynamic>)
            .map((e) => e.toString())
            .toList();

    return Term(
      id: row['id'] as String,
      acronym: row['acronym'] as String,
      fullNameEn: row['full_name_en'] as String,
      fullNameVi: row['full_name_vi'] as String,
      shortDefinition: row['short_definition'] as String,
      detailedExplanation: row['detailed_explanation'] as String?,
      metaphorAnalogy: row['metaphor_analogy'] as String?,
      diagramUrl: row['diagram_url'] as String?,
      categoryTags: decodeStringList(row['category_tags']),
      difficulty: row['difficulty'] as String,
      prerequisites: decodeStringList(row['prerequisites']),
      relatedTerms: decodeStringList(row['related_terms']),
      career: row['career'] as String?,
      concept: row['concept'] as String?,
      attribution: (jsonDecode(row['source_attribution'] as String? ?? '[]')
              as List<dynamic>)
          .map((e) => Attribution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Delta Sync: ghi đè các term cập nhật (ConflictAlgorithm.replace) + cập nhật
  /// quan hệ prerequisite/related. Trả về số term đã ghi.
  Future<int> upsertTerms(List<Term> terms) async {
    final db = await database;
    final batch = db.batch();
    for (final t in terms) {
      batch.insert('terms', _termToRow(t), conflictAlgorithm: ConflictAlgorithm.replace);
      batch.delete('local_term_relationships',
          where: 'child_id = ? AND relation_type = ?', whereArgs: [t.id, 'prerequisite']);
      batch.delete('local_term_relationships',
          where: 'parent_id = ? AND relation_type = ?', whereArgs: [t.id, 'related']);
      for (final p in t.prerequisites) {
        batch.insert('local_term_relationships',
            {'parent_id': p, 'child_id': t.id, 'relation_type': 'prerequisite'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final r in t.relatedTerms) {
        batch.insert('local_term_relationships',
            {'parent_id': t.id, 'child_id': r, 'relation_type': 'related'},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    await batch.commit(noResult: true);
    return terms.length;
  }

  Future<void> deleteTerms(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.generate(ids.length, (_) => '?').join(',');
    await db.delete('terms', where: 'id IN ($placeholders)', whereArgs: ids);
    await db.delete('local_term_relationships', where: 'parent_id IN ($placeholders)', whereArgs: ids);
    await db.delete('local_term_relationships', where: 'child_id IN ($placeholders)', whereArgs: ids);
  }

  Map<String, Object?> _termToRow(Term t) => {
        'id': t.id,
        'acronym': t.acronym,
        'full_name_en': t.fullNameEn,
        'full_name_vi': t.fullNameVi,
        'short_definition': t.shortDefinition,
        'detailed_explanation': t.detailedExplanation,
        'metaphor_analogy': t.metaphorAnalogy,
        'diagram_url': t.diagramUrl,
        'category_tags': jsonEncode(t.categoryTags),
        'difficulty': t.difficulty,
        'prerequisites': jsonEncode(t.prerequisites),
        'related_terms': jsonEncode(t.relatedTerms),
        'career': t.career,
        'concept': t.concept,
        'source_attribution': jsonEncode(t.attribution.map((a) => a.toJson()).toList()),
      };

  static const _cursorKey = 'last_pulled_at';
  static const _contributorKey = 'contributor_name';

  Future<String?> getMeta(String key) async {
    final db = await database;
    final row = await db.query('sync_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return row.isEmpty ? null : row.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getSyncCursor() async => int.tryParse(await getMeta(_cursorKey) ?? '') ?? 0;

  Future<void> setSyncCursor(int epochSeconds) => setMeta(_cursorKey, epochSeconds.toString());

  /// FR-COMM-01: giữ tên người đóng góp giữa các phiên, không bắt buộc tài khoản.
  Future<String?> getContributorName() => getMeta(_contributorKey);

  Future<void> setContributorName(String name) => setMeta(_contributorKey, name.trim());
}
