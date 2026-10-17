import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onAddPressed,
    super.key,
  });

  static const double referenceHeight = 70;
  static const Color activeColor = Color(0xFF7C3AED);
  static const Color inactiveColor = Color(0xFF94A3B8);

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(label: 'Home', icon: Icons.home_outlined),
    _NavItemData(label: 'Orbits', icon: Icons.blur_circular_outlined),
    _NavItemData(label: 'Moments', icon: Icons.photo_library_outlined),
    _NavItemData(label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        border: Border(top: BorderSide(color: Color(0x14000000), width: 1)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 0),
        child: SizedBox(
          height: referenceHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Row(
                  children: <Widget>[
                    _NavItem(
                      item: _items[0],
                      selected: selectedIndex == 0,
                      onTap: () => onTabSelected(0),
                    ),
                    _NavItem(
                      item: _items[1],
                      selected: selectedIndex == 1,
                      onTap: () => onTabSelected(1),
                    ),
                    const SizedBox(width: 56),
                    _NavItem(
                      item: _items[2],
                      selected: selectedIndex == 2,
                      onTap: () => onTabSelected(2),
                    ),
                    _NavItem(
                      item: _items[3],
                      selected: selectedIndex == 3,
                      onTap: () => onTabSelected(3),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Add',
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x807C5CFC),
                            offset: Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onAddPressed,
                          customBorder: const CircleBorder(),
                          child: const SizedBox.square(
                            dimension: 48,
                            child: Icon(
                              Icons.add_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppBottomNavigationBar.activeColor
        : AppBottomNavigationBar.inactiveColor;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
