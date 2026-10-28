import 'package:flutter/material.dart';

import '../contribute/contribution_screen.dart';
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

  static const _pages = [
    SearchScreen(),
    RoadmapScreen(),
    DecoderScreen(),
    QuizScreen(),
    ContributionScreen(),
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
          NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Lộ trình'),
          NavigationDestination(icon: Icon(Icons.auto_fix_high_outlined), label: 'Giải mã'),
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Ôn tập'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Đóng góp'),
        ],
      ),
    );
  }
}
