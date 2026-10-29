import 'package:flutter/material.dart';

import '../../data/glossary_repository.dart';
import '../../data/models/term.dart';
import '../contribute/contribution_screen.dart';
import '../detail/term_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _repo = GlossaryRepository.instance;
  List<SearchResult> _results = const [];
  bool _ready = false;
  bool _syncing = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _repo.warmUp().then((_) => setState(() => _ready = true));
    _loadSyncTime();
  }

  Future<void> _loadSyncTime() async {
    final at = await _repo.lastSyncAt();
    if (!mounted) return;
    setState(() => _lastSync = at);
  }

  /// Delta Sync: kéo cập nhật từ server về SQLite (khi có mạng).
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final res = await _repo.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _loadSyncTime();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        res.ok
            ? 'Đồng bộ xong: ${res.updated} term cập nhật, ${res.deleted} xóa.'
            : 'Không kết nối được máy chủ — app vẫn chạy offline.',
      ),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _results = _repo.search(value);
    });
  }

  void _openTerm(SearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermDetailScreen(termId: result.term.id),
      ),
    );
  }

  void _openContribute() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContributionScreen()));
  }

  /// Cho thấy quy mô kho dữ liệu đang có trên máy, không chỉ "offline" chung chung.
  String _librarySummary() {
    if (!_ready) return 'Đang nạp kho thuật ngữ…';
    final n = _repo.termCount;
    if (n == 0) return 'Chưa có dữ liệu offline — bấm nút đồng bộ ở góc phải.';
    final multi = _repo.corroboratedConceptCount;
    final base = '$n thuật ngữ — 3 tầng tri thức, hoạt động offline';
    return multi == 0 ? base : '$base · $multi khái niệm có ≥2 nguồn xác nhận';
  }

  String _syncCaption() {
    if (_lastSync == null) return 'Chưa đồng bộ — đang dùng bộ dữ liệu đóng gói trong app';
    return 'Đồng bộ gần nhất: ${_ago(_lastSync!)}';
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inHours < 1) return '${d.inMinutes} phút trước';
    if (d.inDays < 1) return '${d.inHours} giờ trước';
    if (d.inDays < 30) return '${d.inDays} ngày trước';
    return at.toLocal().toString().split(' ').first;
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
                            Text('IT Glossary',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text(_librarySummary(),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    )),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đồng bộ cập nhật từ máy chủ',
                        onPressed: _ready && !_syncing ? _sync : null,
                        icon: _syncing
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_sync_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: _ready ? _onQueryChanged : null,
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
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_syncCaption(), style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
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
                          : _BrowsePlaceholder(
                              onPick: (t) {
                                _controller.text = t;
                                _onQueryChanged(t);
                              },
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
  const _NoMatchState({required this.query, required this.onClear, required this.onContribute});

  final String query;
  final VoidCallback onClear;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 52, color: scheme.outline),
            const SizedBox(height: 12),
            Text('Không có mục từ khớp với “$query”',
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Thử viết tắt ngắn hơn (K8s thay vì Kubernetes) hoặc bỏ dấu cách thừa.\n'
              'Nếu thuật ngữ chưa có trong kho, bạn có thể gửi đề xuất để chuyên gia kiểm duyệt.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
                OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.backspace_outlined),
                    label: const Text('Xóa từ khóa')),
              ],
            ),
          ],
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
        if (icon != null) ...[Icon(icon, size: 12, color: scheme.onPrimaryContainer), const SizedBox(width: 3)],
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                term.acronym,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (result.similarity > 0 && result.similarity < 1)
              _badge(context, '${(result.similarity * 100).round()}%'),
            if (result.siblingCount > 0)
              _badge(context, '${result.siblingCount + 1} nguồn',
                  icon: Icons.fact_check_outlined),
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
            Text(term.shortDefinition,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            if (alias?.namingRuleNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(alias!.namingRuleNote!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).colorScheme.tertiary)),
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

class _BrowsePlaceholder extends StatelessWidget {
  const _BrowsePlaceholder({required this.onPick});

  final ValueChanged<String> onPick;

  static const _popular = ['API', 'K8s', 'JWT', 'Docker', 'REST', 'CI/CD'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore,
                size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Khám phá thuật ngữ IT',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Nhập từ khóa để bắt đầu. Thử với các thuật ngữ phổ biến:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _popular
                  .map((t) => ActionChip(label: Text(t), onPressed: () => onPick(t)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
