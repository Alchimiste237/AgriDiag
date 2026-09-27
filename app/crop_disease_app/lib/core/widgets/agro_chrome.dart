import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The five destinations of the bottom navigation bar from the design:
/// Home · History · Scanner (center, raised green dot) · Advice · Profile.
enum AgroTab { home, history, scanner, advice, profile }

/// White bottom navigation bar with the center Scanner action.
///
/// [currentTab] highlights the active destination; [onTabSelected] is called
/// with the tapped tab. The scanner tab is drawn as a raised green circle
/// exactly like the design.
class AgroBottomNavBar extends StatelessWidget {
  final AgroTab currentTab;
  final ValueChanged<AgroTab> onTabSelected;

  const AgroBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: currentTab == AgroTab.home,
                onTap: () => onTabSelected(AgroTab.home),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                activeIcon: Icons.history_rounded,
                label: 'History',
                selected: currentTab == AgroTab.history,
                onTap: () => onTabSelected(AgroTab.history),
              ),
              _ScannerItem(
                selected: currentTab == AgroTab.scanner,
                onTap: () => onTabSelected(AgroTab.scanner),
              ),
              _NavItem(
                icon: Icons.tips_and_updates_outlined,
                activeIcon: Icons.tips_and_updates_rounded,
                label: 'Advice',
                selected: currentTab == AgroTab.advice,
                onTap: () => onTabSelected(AgroTab.advice),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: currentTab == AgroTab.profile,
                onTap: () => onTabSelected(AgroTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.inkFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _ScannerItem({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -6),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.greenButtonGradient,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -2),
              child: Text(
                'Scanner',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.green : AppColors.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark-green page header used by the capture and result screens: back
/// button on the left, centered bold white title, optional trailing action.
class AgroPageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AgroPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.deepGreenGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (onBack != null)
                Positioned(
                  left: 6,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                    tooltip: 'Back',
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (actionIcon != null)
                Positioned(
                  right: 6,
                  child: IconButton(
                    onPressed: onAction,
                    icon: Icon(actionIcon,
                        color: Colors.white.withValues(alpha: 0.9), size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
