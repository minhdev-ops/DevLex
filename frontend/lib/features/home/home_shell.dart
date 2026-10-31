import 'package:flutter/material.dart';

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
      onNavigateTab: (i) => setState(() => _index = i),
      onOpenCareer: (career) {
        RoadmapSelection.instance.value = career;
        setState(() => _index = 1);
      },
    ),
    const RoadmapScreen(),
    const DecoderScreen(),
    const QuizScreen(),
    const ContributionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
    );
  }
}
