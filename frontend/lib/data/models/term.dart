class Attribution {
  const Attribution({
    required this.component,
    required this.source,
    required this.author,
    required this.license,
    required this.authorLink,
    required this.modificationStatus,
    this.authorityTier,
    this.confidence,
  });

  final String component;
  final String source;
  final String author;
  final String license;
  final String authorLink;
  final String modificationStatus;

  /// Bậc thẩm quyền nguồn: 1 = tổ chức chuẩn hóa/chính phủ (NIST, MDN), 2 = liên minh CN.
  final int? authorityTier;

  /// Độ tin cậy 0–100 sau chấm điểm đa nguồn (corroboration).
  final int? confidence;

  bool get isVerified => authorityTier == 1;

  factory Attribution.fromJson(Map<String, dynamic> json) => Attribution(
        component: json['component'] as String? ?? '',
        source: json['source'] as String? ?? '',
        author: json['author'] as String? ?? '',
        license: json['license'] as String? ?? '',
        authorLink: json['authorLink'] as String? ?? json['author_link'] as String? ?? '',
        modificationStatus:
            json['modificationStatus'] as String? ?? json['modification_status'] as String? ?? '',
        authorityTier: json['authorityTier'] as int? ?? json['authority_tier'] as int?,
        confidence: json['confidence'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'component': component,
        'source': source,
        'author': author,
        'license': license,
        'authorLink': authorLink,
        'modificationStatus': modificationStatus,
        if (authorityTier != null) 'authority_tier': authorityTier,
        if (confidence != null) 'confidence': confidence,
      };
}

class Term {
  const Term({
    required this.id,
    required this.acronym,
    required this.fullNameEn,
    required this.fullNameVi,
    required this.shortDefinition,
    required this.detailedExplanation,
    required this.metaphorAnalogy,
    required this.diagramUrl,
    required this.categoryTags,
    required this.difficulty,
    required this.prerequisites,
    required this.relatedTerms,
    required this.career,
    required this.attribution,
  });

  final String id;
  final String acronym;
  final String fullNameEn;
  final String fullNameVi;
  final String shortDefinition;
  final String? detailedExplanation;
  final String? metaphorAnalogy;
  final String? diagramUrl;
  final List<String> categoryTags;
  final String difficulty;
  final List<String> prerequisites;
  final List<String> relatedTerms;
  final String? career;
  final List<Attribution> attribution;

  factory Term.fromJson(Map<String, dynamic> json) => Term(
        id: json['id'] as String,
        acronym: json['acronym'] as String,
        fullNameEn: json['fullNameEn'] as String,
        fullNameVi: json['fullNameVi'] as String,
        shortDefinition: json['shortDefinition'] as String,
        detailedExplanation: json['detailedExplanation'] as String?,
        metaphorAnalogy: json['metaphorAnalogy'] as String?,
        diagramUrl: json['diagramUrl'] as String?,
        categoryTags: (json['categoryTags'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        difficulty: json['difficulty'] as String? ?? 'Beginner',
        prerequisites:
            (json['prerequisites'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        relatedTerms:
            (json['relatedTerms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        career: json['career'] as String?,
        attribution: (json['attribution'] as List<dynamic>? ?? [])
            .map((e) => Attribution.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'acronym': acronym,
        'fullNameEn': fullNameEn,
        'fullNameVi': fullNameVi,
        'shortDefinition': shortDefinition,
        'detailedExplanation': detailedExplanation,
        'metaphorAnalogy': metaphorAnalogy,
        'diagramUrl': diagramUrl,
        'categoryTags': categoryTags,
        'difficulty': difficulty,
        'prerequisites': prerequisites,
        'relatedTerms': relatedTerms,
        'career': career,
        'attribution': attribution.map((a) => a.toJson()).toList(),
      };
}

class TermAlias {
  const TermAlias({
    required this.termId,
    required this.alias,
    required this.namingRuleNote,
  });

  final String termId;
  final String alias;
  final String? namingRuleNote;

  factory TermAlias.fromJson(Map<String, dynamic> json) => TermAlias(
        termId: json['termId'] as String,
        alias: json['alias'] as String,
        namingRuleNote: json['namingRuleNote'] as String?,
      );
}

class SearchResult {
  const SearchResult({required this.term, required this.similarity, this.matchedAlias});

  final Term term;
  final double similarity;
  final TermAlias? matchedAlias;
}

enum LearnStatus { learned, needsReview }

class StudyState {
  const StudyState({
    required this.termId,
    required this.learned,
    required this.intervalDays,
    required this.dueDate,
    required this.streak,
  });

  static const empty = StudyState(
    termId: '',
    learned: false,
    intervalDays: 0,
    dueDate: null,
    streak: 0,
  );

  final String termId;
  final bool learned;
  final int intervalDays;
  final String? dueDate;
  final int streak;

  factory StudyState.fromRow(Map<String, Object?> row) => StudyState(
        termId: row['term_id'] as String,
        learned: (row['status'] as String) == 'learned',
        intervalDays: (row['interval_days'] as int?) ?? 0,
        dueDate: row['due_date'] as String?,
        streak: (row['streak'] as int?) ?? 0,
      );
}
