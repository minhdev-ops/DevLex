import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/consent.dart';
import '../../core/roadmap_selection.dart';
import '../contribute/contribution_screen.dart';
import '../legal/consent_sheet.dart';
import '../decoder/decoder_screen.dart';
import '../quiz/quiz_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../search/search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Mỗi tab có Navigator riêng để màn hình đẩy lên (chi tiết thuật ngữ, cài
  /// đặt, kiểm duyệt...) vẫn nằm trong tab và thanh điều hướng dưới luôn hiện.
  final _navKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    // Google Play: thông báo quyền riêng tư ở lần mở app đầu tiên.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskConsent());
  }

  Future<void> _maybeAskConsent() async {
    await Consent.instance.load();
    if (!mounted || Consent.instance.accepted.value) return;
    await showConsentSheet(context);
  }

  late final List<Widget> _pages = [
    SearchScreen(
      onNavigateTab: (i) => _selectTab(i),
      onOpenCareer: (career) {
        RoadmapSelection.instance.value = career;
        _selectTab(1);
      },
    ),
    const RoadmapScreen(),
    const DecoderScreen(),
    const QuizScreen(),
    const ContributionScreen(),
  ];

  void _selectTab(int i) {
    // Đổi tab phải hạ bàn phím, nếu không nó che mất nội dung tab mới.
    FocusManager.instance.primaryFocus?.unfocus();
    if (i == _index) {
      // Bấm lại tab đang mở: quay về màn gốc của tab đó.
      _navKeys[i].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = i);
  }

  Widget _tabNavigator(int i) => Navigator(
    key: _navKeys[i],
    onGenerateRoute: (settings) => MaterialPageRoute(
      builder: (_) => _pages[i],
      settings: settings,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < _pages.length; i++) _tabNavigator(i)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Tra cứu'),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: 'Lộ trình',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_fix_high_outlined),
              label: 'Giải mã',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              label: 'Ôn tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Đóng góp',
            ),
          ],
        ),
      ),
    );
  }
}
