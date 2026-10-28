import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';

class TermDetailScreen extends StatelessWidget {
  const TermDetailScreen({super.key, required this.termId});

  final String termId;

  @override
  Widget build(BuildContext context) {
    final term = GlossaryRepository.instance.termById(termId);

    if (term == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thuật ngữ')),
        body: const Center(child: Text('Không tìm thấy thuật ngữ (có thể đã bị xóa khỏi DB cục bộ).')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(term.acronym)),
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
          const SizedBox(height: 16),
          _AttributionCard(attribution: term.attribution),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.color, required this.label, required this.child});

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
                Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        )),
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
        Text(term.acronym,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(term.fullNameEn, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(term.fullNameVi,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 10),
        Text(term.shortDefinition, style: Theme.of(context).textTheme.bodyLarge),
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
        if (explanation.isNotEmpty) Text(explanation, style: Theme.of(context).textTheme.bodyMedium),
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
                const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.tier2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Ẩn dụ: ${term.metaphorAnalogy}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

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
            ...term.categoryTags.map((t) => Chip(
                  label: Text(t),
                  visualDensity: VisualDensity.compact,
                  labelStyle: Theme.of(context).textTheme.labelSmall,
                )),
            Chip(
              label: Text(term.difficulty, style: const TextStyle(fontSize: 11)),
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
          Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
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
                  MaterialPageRoute(builder: (_) => TermDetailScreen(termId: id)),
                ),
              );
            }).toList(),
          ),
        ],
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
                Icon(Icons.account_balance_outlined,
                    size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Thông tin ghi công bản quyền (Attribution)',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            ...attribution.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_componentLabel(a.component)}:  ${a.source} (${a.author}) — ${a.license}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      if (a.modificationStatus.isNotEmpty)
                        Text(a.modificationStatus,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                )),
                      if (a.authorLink.isNotEmpty)
                        InkWell(
                          onTap: () {},
                          child: Text('Xem nguồn gốc:  ${a.authorLink}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                        ),
                    ],
                  ),
                )),
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
