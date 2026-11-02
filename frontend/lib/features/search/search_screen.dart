import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/connectivity_status.dart';
import '../../core/sync_status_pill.dart';
import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';
import '../contribute/contribution_screen.dart';
import '../detail/term_detail_screen.dart';
import '../settings/settings_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.warmUp,
    this.onNavigateTab,
    this.onOpenCareer,
  });

  /// Cho test mô phỏng kho nạp chậm; mặc định nạp kho đóng gói thật.
  final Future<void> Function()? warmUp;

  /// Chuyển tab từ dashboard (Lộ trình / Giải mã / Ôn tập / Đóng góp).
  final ValueChanged<int>? onNavigateTab;

  /// Mở tab Lộ trình và chọn đúng nghề người dùng vừa chạm.
  final ValueChanged<String>? onOpenCareer;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _repo = GlossaryRepository.instance;
  List<SearchResult> _results = const [];
  bool _ready = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final warmUp = widget.warmUp ?? _repo.warmUp;
    warmUp().then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        // Người dùng có thể đã gõ khi kho còn nạp: lúc đó onChanged bị khóa nên
        // phải chạy lại, nếu không một từ khóa hợp lệ bị báo "không có mục từ".
        if (_controller.text.trim().isNotEmpty) {
          _results = _repo.search(_controller.text);
        }
      });
    });
    _repo.progressRevision.addListener(_onProgressChanged);
  }

  /// Tiến độ học đổi ở tab khác (Ôn tập / Lộ trình) thì dashboard phải vẽ lại,
  /// vì IndexedStack giữ nguyên widget và không tự build lại.
  void _onProgressChanged() {
    if (mounted) setState(() {});
  }

  /// Delta Sync: kéo cập nhật từ server về SQLite (khi có mạng).
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final res = await _repo.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    ConnectivityStatus.instance.checkNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_syncMessage(res)),
      ),
    );
  }

  String _syncMessage(SyncOutcome res) {
    if (!res.ok) return 'Không kết nối được máy chủ — app vẫn chạy offline.';
    final summary =
        '${res.updated} thuật ngữ cập nhật, ${res.deleted} thuật ngữ đã xóa.';
    return res.partial
        ? 'Đồng bộ một phần: $summary Sẽ tiếp tục ở lần sau.'
        : 'Đồng bộ xong: $summary';
  }

  @override
  void dispose() {
    _repo.progressRevision.removeListener(_onProgressChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _results = _repo.search(value);
    });
  }

  Future<void> _openTerm(SearchResult result) async {
    _focus.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermDetailScreen(termId: result.term.id),
      ),
    );
    // Quay lại: trạng thái đã học và mục "Tiếp tục học" có thể vừa đổi.
    if (mounted) setState(() {});
  }

  Future<void> _openTermById(String id) async {
    _focus.unfocus();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TermDetailScreen(termId: id)));
    if (mounted) setState(() {});
  }

  Future<void> _openContribute() async {
    _focus.unfocus();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ContributionScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (mounted) setState(() {});
  }

  /// Một dòng ngắn về quy mô kho dữ liệu — đủ tin, không chiếm chỗ của kết quả.
  String _librarySummary() {
    if (!_ready) return 'Đang nạp kho thuật ngữ…';
    final n = _repo.termCount;
    if (n == 0) return 'Chưa có dữ liệu offline — bấm nút đồng bộ ở góc phải.';
    return '${_groupThousands(n)} thuật ngữ · dùng offline';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IT Glossary',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _librarySummary(),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đồng bộ cập nhật từ máy chủ',
                        onPressed: _ready && !_syncing ? _sync : null,
                        icon: _syncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_outlined),
                      ),
                      IconButton(
                        tooltip: 'Cài đặt & nguồn dữ liệu',
                        onPressed: _openSettings,
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: _ready ? _onQueryChanged : null,
                    // Enter/ô tìm kiếm xong là hạ bàn phím, đừng để nó che
                    // danh sách kết quả.
                    onSubmitted: (_) => _focus.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Thử tìm: API, K8s, JWT, Docker...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa từ khóa',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                                _focus.unfocus();
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SyncStatusPill(onSync: _sync, syncing: _syncing),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _TermResultTile(
                        result: _results[index],
                        onTap: () => _openTerm(_results[index]),
                      ),
                    )
                  : _controller.text.isNotEmpty
                  ? _NoMatchState(
                      query: _controller.text,
                      onClear: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      onContribute: _openContribute,
                    )
                  : _HomeDashboard(
                      repo: _repo,
                      onPick: (t) {
                        _controller.text = t;
                        _onQueryChanged(t);
                      },
                      onOpenTerm: (t) => _openTermById(t.id),
                      onNavigateTab: widget.onNavigateTab,
                      onOpenCareer: widget.onOpenCareer,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Không có kết quả là lúc dễ mất người dùng nhất: chỉ rõ cách sửa từ khóa
/// và cho gửi thẳng thuật ngữ còn thiếu lên hàng chờ kiểm duyệt.
class _NoMatchState extends StatelessWidget {
  const _NoMatchState({
    required this.query,
    required this.onClear,
    required this.onContribute,
  });

  final String query;
  final VoidCallback onClear;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Bàn phím mở làm khung nhìn co lại: nội dung phải cuộn được, nếu không
    // cột tràn ra ngoài (lỗi "overflowed by 78 pixels" khi từ khóa dài).
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight.isFinite
                ? (box.maxHeight - 56).clamp(0.0, double.infinity)
                : 0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 52, color: scheme.outline),
              const SizedBox(height: 12),
              Text(
                'Không có mục từ khớp với “$query”',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Thử viết tắt ngắn hơn (K8s thay vì Kubernetes) hoặc bỏ dấu cách thừa.\n'
                'Nếu thuật ngữ chưa có trong kho, bạn có thể gửi đề xuất để chuyên gia kiểm duyệt.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onContribute,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Đóng góp thuật ngữ này'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Xóa từ khóa'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _badge(BuildContext context, String label, {IconData? icon}) {
  final scheme = Theme.of(context).colorScheme;

  return Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: scheme.onPrimaryContainer),
          const SizedBox(width: 3),
        ],
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _TermResultTile extends StatelessWidget {
  const _TermResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final term = result.term;
    final alias = result.matchedAlias;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        // Mũi tên cho biết cả thẻ bấm được, không chỉ dòng chữ.
        trailing: const Icon(Icons.chevron_right),
        title: Row(
          children: [
            Expanded(
              child: Text(
                term.acronym,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (result.similarity > 0 && result.similarity < 1)
              _badge(context, '${(result.similarity * 100).round()}%'),
            if (result.siblingCount > 0)
              _badge(
                context,
                '${result.siblingCount + 1} nguồn',
                icon: Icons.fact_check_outlined,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.bilingualName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              term.shortDefinition,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (alias?.namingRuleNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alias!.namingRuleNote!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Trang chủ khi ô tìm kiếm còn trống: trả lời ngay "học gì tiếp?" thay vì
/// bắt người dùng tự nghĩ ra từ khóa.
class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.repo,
    required this.onPick,
    required this.onOpenTerm,
    this.onNavigateTab,
    this.onOpenCareer,
  });

  final GlossaryRepository repo;
  final ValueChanged<String> onPick;
  final ValueChanged<Term> onOpenTerm;
  final ValueChanged<int>? onNavigateTab;
  final ValueChanged<String>? onOpenCareer;

  static const _popular = ['API', 'K8s', 'JWT', 'Docker', 'REST', 'CI/CD'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = repo.studyStats();
    final recent = repo.recentTerms();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _HeroCard(termCount: repo.termCount),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.account_tree_outlined,
                label: 'Lộ trình',
                onTap: onNavigateTab == null ? null : () => onNavigateTab!(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickAction(
                icon: Icons.auto_fix_high_outlined,
                label: 'Giải mã JD',
                onTap: onNavigateTab == null ? null : () => onNavigateTab!(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickAction(
                icon: Icons.style_outlined,
                label: 'Ôn tập',
                onTap: onNavigateTab == null ? null : () => onNavigateTab!(3),
              ),
            ),
          ],
        ),
        if (stats.dueNow > 0) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stats.dueNow} thẻ đến hạn ôn hôm nay',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Chu kỳ 1 → 3 → 7 ngày giúp nhớ lâu hơn',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onNavigateTab == null
                        ? null
                        : () => onNavigateTab!(3),
                    child: const Text('Ôn ngay'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Tiếp tục học',
            action: recent.length > 3 ? 'Xem thêm' : null,
            onAction: onNavigateTab == null ? null : () => onNavigateTab!(3),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _RecentCard(
                term: recent[i],
                state: repo.cachedStudyState(recent[i].id),
                onTap: () => onOpenTerm(recent[i]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Lộ trình nghề nghiệp'),
        const SizedBox(height: 8),
        for (final entry in GlossaryRepository.careers.entries) ...[
          _CareerProgressCard(
            label: entry.value,
            progress: repo.careerProgressSync(entry.key),
            counts: repo.careerCounts(entry.key),
            onTap: onOpenCareer == null && onNavigateTab == null
                ? null
                : () {
                    if (onOpenCareer != null) {
                      onOpenCareer!(entry.key);
                    } else {
                      onNavigateTab!(1);
                    }
                  },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const _SectionTitle(title: 'Thuật ngữ phổ biến'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popular
              .map(
                (t) => ActionChip(label: Text(t), onPressed: () => onPick(t)),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Không cần mạng — toàn bộ kho nằm trong máy',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.termCount});

  final int termCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_outlined, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'DevLex',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_groupThousands(termCount)} thuật ngữ IT',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '3 tầng định nghĩa · lộ trình nghề · dùng offline',
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.term,
    required this.state,
    required this.onTap,
  });

  final Term term;
  final StudyState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 176,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        term.acronym,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      state.learned
                          ? Icons.check_circle
                          : (state.needsReview
                                ? Icons.refresh
                                : Icons.schedule),
                      size: 15,
                      color: state.learned
                          ? AppTheme.tier2
                          : (state.needsReview
                                ? AppTheme.warning
                                : scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  term.shortDefinition,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  state.statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerProgressCard extends StatelessWidget {
  const _CareerProgressCard({
    required this.label,
    required this.progress,
    required this.counts,
    this.onTap,
  });

  final String label;
  final int progress;
  final (int done, int total) counts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${counts.$1}/${counts.$2} · $progress%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
