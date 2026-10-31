import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';

class TermDetailScreen extends StatefulWidget {
  const TermDetailScreen({super.key, required this.termId});

  final String termId;

  @override
  State<TermDetailScreen> createState() => _TermDetailScreenState();
}

class _TermDetailScreenState extends State<TermDetailScreen> {
  final _repo = GlossaryRepository.instance;

  @override
  void initState() {
    super.initState();
    // FR-QUIZ-01: mở bài viết cũng là một lần "đã xem" -> đủ điều kiện vào đề
    // trắc nghiệm dù người dùng chưa bấm đánh dấu học.
    _repo.recordView(widget.termId).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final term = _repo.termById(widget.termId);

    if (term == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thuật ngữ')),
        body: const Center(
          child: Text(
            'Không tìm thấy thuật ngữ (có thể đã bị xóa khỏi DB cục bộ).',
          ),
        ),
      );
    }

    final maxConfidence = term.attribution
        .map((a) => a.confidence ?? 0)
        .fold<int>(0, (prev, el) => el > prev ? el : prev);
    final trusted =
        term.attribution.any((a) => a.isVerified) || maxConfidence >= 90;
    // SRS mục 4: một khái niệm có thể được nhiều nguồn định nghĩa -> cộng hưởng
    // điểm tin cậy, tính offline từ khóa concept mà delta sync mang về.
    final trust = _repo.trustFor(term);
    final study = _repo.cachedStudyState(term.id);
    final learned = study.learned;
    final needsReview = study.needsReview;

    return Scaffold(
      appBar: AppBar(
        title: Text(term.acronym),
        actions: [
          IconButton(
            icon: Icon(
              learned
                  ? Icons.check_circle
                  : (needsReview
                        ? Icons.refresh
                        : Icons.radio_button_unchecked),
              color: learned
                  ? AppTheme.tier2
                  : (needsReview ? AppTheme.warning : null),
            ),
            tooltip: learned ? 'Bỏ đánh dấu đã học' : 'Đánh dấu đã học',
            onPressed: () async {
              await _repo.toggleLearned(term.id);
              if (!context.mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    learned
                        ? 'Đã chuyển ${term.acronym} sang Cần ôn tập.'
                        : 'Đã thêm ${term.acronym} vào hàng chờ ôn tập.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          if (trusted)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: AppTheme.tier1.withValues(alpha: 0.12),
                label: Text(
                  trust.confidence > 0
                      ? '✓ Nguồn uy tín · ${trust.confidence}'
                      : '✓ Nguồn uy tín',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _TierCard(
            color: AppTheme.tier1,
            label: 'TẦNG 1 — ĐỊNH NGHĨA CƠ BẢN',
            child: _Tier1Body(term: term),
          ),
          if (term.detailedExplanation != null || term.metaphorAnalogy != null)
            _TierCard(
              color: AppTheme.tier2,
              label: 'TẦNG 2 — BỐI CẢNH & TRỰC QUAN',
              child: _Tier2Body(term: term),
            ),
          _TierCard(
            color: AppTheme.tier3,
            label: 'TẦNG 3 — MỐI QUAN HỆ & LỘ TRÌNH',
            child: _Tier3Body(term: term),
          ),
          const SizedBox(height: 4),
          _LearningActionCard(
            state: study,
            onToggle: () async {
              await _repo.toggleLearned(term.id);
              if (context.mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _TrustCard(trust: trust),
          const SizedBox(height: 12),
          _AttributionCard(attribution: term.attribution),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.color,
    required this.label,
    required this.child,
  });

  final Color color;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tier1Body extends StatelessWidget {
  const _Tier1Body({required this.term});

  final Term term;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          term.acronym,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          term.fullNameEn,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (term.needsTranslation)
          Text(
            'Chưa có bản dịch tiếng Việt — giữ nguyên cách gọi của nguồn (issue #1).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Text(
            term.fullNameVi,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          term.shortDefinition,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _Tier2Body extends StatelessWidget {
  const _Tier2Body({required this.term});

  final Term term;

  @override
  Widget build(BuildContext context) {
    final explanation = (term.detailedExplanation ?? '')
        .replaceAll('### ', '')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (explanation.isNotEmpty)
          Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
        if (term.metaphorAnalogy != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tier2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.tier2.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppTheme.tier2,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ẩn dụ: ${term.metaphorAnalogy}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _ContextDiagram(term: term),
      ],
    );
  }
}

/// FR-GLOS-04 (Tầng 2): sơ đồ luồng hoạt động đơn giản hóa. Khi nguồn có ảnh
/// diagram_url thì hiển thị ảnh; nếu không, dựng sơ đồ tóm tắt từ quan hệ
/// prerequisite/related đã có trong kho — vẫn trực quan và không bịa dữ liệu.
class _ContextDiagram extends StatelessWidget {
  const _ContextDiagram({required this.term});

  final Term term;

  @override
  Widget build(BuildContext context) {
    final repo = GlossaryRepository.instance;
    final prerequisites = term.prerequisites
        .map(repo.termById)
        .whereType<Term>()
        .take(2)
        .toList();
    final related = term.relatedTerms
        .map(repo.termById)
        .whereType<Term>()
        .take(2)
        .toList();

    final url = (term.diagramUrl ?? '').trim();
    if (url.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _FlowBoard(
                term: term,
                prerequisites: prerequisites,
                related: related,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sơ đồ luồng hoạt động',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      );
    }

    return _FlowBoard(
      term: term,
      prerequisites: prerequisites,
      related: related,
    );
  }
}

class _FlowBoard extends StatelessWidget {
  const _FlowBoard({
    required this.term,
    required this.prerequisites,
    required this.related,
  });

  final Term term;
  final List<Term> prerequisites;
  final List<Term> related;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: AppTheme.tier2),
              const SizedBox(width: 6),
              Text(
                'Sơ đồ luồng hoạt động (tóm tắt)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.tier2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 360;
              final side = [
                _FlowSide(
                  label: 'Cần biết trước',
                  terms: prerequisites,
                  emptyLabel: 'Bắt đầu',
                  tone: AppTheme.tier1,
                ),
                _FlowSide(
                  label: 'Mở rộng',
                  terms: related,
                  emptyLabel: 'Chưa có liên kết',
                  tone: AppTheme.tier3,
                ),
              ];
              final center = _FlowNode(
                term: term,
                tone: AppTheme.tier2,
                highlight: true,
                onTap: null,
              );

              if (!wide) {
                return Column(
                  children: [
                    side[0],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Icon(Icons.arrow_downward, size: 16),
                    ),
                    center,
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Icon(Icons.arrow_downward, size: 16),
                    ),
                    side[1],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: side[0]),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(child: center),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(child: side[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Chạm một thuật ngữ để mở bài viết tương ứng.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FlowSide extends StatelessWidget {
  const _FlowSide({
    required this.label,
    required this.terms,
    required this.emptyLabel,
    required this.tone,
  });

  final String label;
  final List<Term> terms;
  final String emptyLabel;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: tone,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        if (terms.isEmpty)
          Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final t in terms)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _FlowNode(term: t, tone: tone, highlight: false),
            ),
      ],
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.term,
    required this.tone,
    required this.highlight,
    this.onTap,
  });

  final Term term;
  final Color tone;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: highlight ? tone.withValues(alpha: 0.14) : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap:
            onTap ??
            (highlight
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TermDetailScreen(termId: term.id),
                    ),
                  )),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tone.withValues(alpha: highlight ? 0.8 : 0.4),
            ),
          ),
          child: Text(
            term.acronym,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? tone : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

String _difficultyLabel(String value) => switch (value.trim().toLowerCase()) {
  'beginner' => 'Cơ bản',
  'intermediate' => 'Trung cấp',
  'advanced' => 'Nâng cao',
  _ => value,
};

class _Tier3Body extends StatelessWidget {
  const _Tier3Body({required this.term});

  final Term term;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...term.categoryTags.map(
              (t) => Chip(
                label: Text(t),
                visualDensity: VisualDensity.compact,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Chip(
              avatar: const Icon(Icons.signal_cellular_alt, size: 14),
              label: Text(
                _difficultyLabel(term.difficulty),
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        _TermLinkGroup(
          title: 'Cần biết trước (prerequisites)',
          termIds: term.prerequisites,
        ),
        _TermLinkGroup(
          title: 'Khám phá tiếp (related terms)',
          termIds: term.relatedTerms,
        ),
      ],
    );
  }
}

class _TermLinkGroup extends StatelessWidget {
  const _TermLinkGroup({required this.title, required this.termIds});

  final String title;
  final List<String> termIds;

  @override
  Widget build(BuildContext context) {
    if (termIds.isEmpty) return const SizedBox.shrink();
    final repo = GlossaryRepository.instance;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: termIds.map((id) {
              final linked = repo.termById(id);
              if (linked == null) return const SizedBox.shrink();
              return ActionChip(
                label: Text(linked.acronym),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TermDetailScreen(termId: id),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LearningActionCard extends StatelessWidget {
  const _LearningActionCard({required this.state, required this.onToggle});

  final StudyState state;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final learned = state.learned;
    final tone = learned
        ? AppTheme.tier2
        : (state.needsReview ? AppTheme.warning : AppTheme.tier1);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  learned
                      ? Icons.check_circle
                      : (state.needsReview ? Icons.refresh : Icons.schedule),
                  color: tone,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trạng thái học của bạn',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              learned
                  ? 'Thẻ đang nằm trong lịch ôn 1 → 3 → 7 ngày. Bạn có thể chuyển lại Cần ôn tập nếu thấy chưa chắc.'
                  : 'Đánh dấu đã học để đưa thẻ vào lịch ôn ngắt quãng và tính vào tiến độ lộ trình.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: learned
                  ? OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Chuyển sang Cần ôn tập'),
                    )
                  : FilledButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Đánh dấu đã học & thêm vào ôn tập'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.trust});

  final ConceptTrust trust;

  @override
  Widget build(BuildContext context) {
    final n = trust.agreeingSources.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: AppTheme.tier1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mức tin cậy (chấm điểm đa nguồn)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${trust.confidence}/100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.tier1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              n > 1
                  ? '$n nguồn độc lập cùng định nghĩa khái niệm này: ${trust.agreeingSources.join(', ')}'
                  : (n == 1
                        ? 'Một nguồn: ${trust.agreeingSources.first}'
                        : 'Chưa có thông tin nguồn cho khái niệm này.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ...trust.contexts.map(
              (sibling) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TermDetailScreen(termId: sibling.id),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sibling.attribution.isEmpty ? '' : '${sibling.attribution.first.source} · '}${sibling.acronym}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        sibling.shortDefinition,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributionCard extends StatelessWidget {
  const _AttributionCard({required this.attribution});

  final List<Attribution> attribution;

  @override
  Widget build(BuildContext context) {
    if (attribution.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Thông tin ghi công bản quyền (Attribution)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...attribution.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_componentLabel(a.component)}:  ${a.source} (${a.author}) — ${a.license}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.modificationStatus.isNotEmpty)
                      Text(
                        a.modificationStatus,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (a.authorLink.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(a.authorLink);
                          if (uri == null ||
                              !(uri.isScheme('http') ||
                                  uri.isScheme('https'))) {
                            return;
                          }
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Text(
                          'Xem nguồn gốc:  ${a.authorLink}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _componentLabel(String component) => switch (component) {
    'tier_1' => 'Định nghĩa cơ bản (Tầng 1)',
    'tier_2' => 'Giải thích chi tiết (Tầng 2)',
    'tier_3' => 'Mối quan hệ & lộ trình (Tầng 3)',
    _ => component,
  };
}
