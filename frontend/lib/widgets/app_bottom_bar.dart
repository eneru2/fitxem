import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fitxem/theme/app_theme.dart';

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _animDuration = Duration(milliseconds: 320);
  static const _animCurve = Curves.easeInOutCubic;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    _NavItem(label: 'Fichar', icon: CupertinoIcons.clock),
    _NavItem(label: 'Historial', icon: CupertinoIcons.list_bullet),
    _NavItem(label: 'Admin', icon: CupertinoIcons.briefcase),
    _NavItem(label: 'Ajustes', icon: CupertinoIcons.sun_max),
  ];

  Alignment _alignmentFor(int index, int count) {
    if (count <= 1) return Alignment.center;
    final fraction = index / (count - 1);
    return Alignment(fraction * 2 - 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.navBar,
          borderRadius: BorderRadius.circular(AppTheme.radiusNav),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppTheme.navBarHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedAlign(
                  duration: _animDuration,
                  curve: _animCurve,
                  alignment: _alignmentFor(selectedIndex, _items.length),
                  child: FractionallySizedBox(
                    widthFactor: 1 / _items.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.navBarActive,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _NavButton(
                          item: _items[i],
                          selected: selectedIndex == i,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  void _handleTap() {
    HapticFeedback.selectionClick();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedAlign(
            duration: AppBottomBar._animDuration,
            curve: AppBottomBar._animCurve,
            alignment: selected ? const Alignment(0, -0.35) : Alignment.center,
            child: AnimatedOpacity(
              duration: AppBottomBar._animDuration,
              curve: AppBottomBar._animCurve,
              opacity: selected ? 1 : 0.45,
              child: Icon(item.icon, size: 20, color: Colors.white),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            bottom: 10,
            child: IgnorePointer(
              ignoring: !selected,
              child: AnimatedOpacity(
                duration: AppBottomBar._animDuration,
                curve: AppBottomBar._animCurve,
                opacity: selected ? 1 : 0,
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.navLabel(selected: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
