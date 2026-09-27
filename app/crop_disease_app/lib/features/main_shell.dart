import 'package:flutter/material.dart';
import '../core/config/app_theme.dart';
import '../core/widgets/agro_chrome.dart';
import 'advice/advice_screen.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'scan/capture_screen.dart';

/// Hosts the five bottom-navigation destinations from the design:
/// Home · History · Scanner · Advice · Profile.
///
/// The Scanner tab pushes the full-screen [CaptureScreen] as a route rather
/// than switching tabs — like the design, the scanner is a task page, not a
/// tab of its own. Tabs are kept alive in an [IndexedStack] so state (scroll
/// positions, loaded scans) survives tab switches.

/// Maps an [AgroTab] to its child index in [MainShell]'s [IndexedStack].
/// The stack hosts only the 4 real tabs — scanner is not a child (it pushes
/// a route), so indices skip it. Exposed top-level for testing.
int agroTabIndex(AgroTab tab) => switch (tab) {
      AgroTab.home => 0,
      AgroTab.history => 1,
      AgroTab.advice => 2,
      AgroTab.profile => 3,
      AgroTab.scanner => 0, // never a stack child; falls back to Home
    };
class MainShell extends StatelessWidget {
  final AgroTab initialTab;

  const MainShell({super.key, this.initialTab = AgroTab.home});

  @override
  Widget build(BuildContext context) {
    return _MainShellStateful(initialTab: initialTab);
  }
}

class _MainShellStateful extends StatefulWidget {
  final AgroTab initialTab;

  const _MainShellStateful({required this.initialTab});

  @override
  State<_MainShellStateful> createState() => _MainShellStatefulState();
}

class _MainShellStatefulState extends State<_MainShellStateful> {
  late AgroTab _tab = widget.initialTab;

  void _onTabSelected(AgroTab tab) {
    if (tab == AgroTab.scanner) {
      // The scanner is a full-screen task — push the capture page.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CaptureScreen()),
      );
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(
        index: agroTabIndex(_tab),
        children: const [
          HomeScreen(embedded: true),
          HistoryScreen(embedded: true),
          AdviceScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AgroBottomNavBar(
        currentTab: _tab,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}
