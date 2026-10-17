import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/models/orbit_models.dart';
import '../widgets/orbit_gift_grid.dart';
import '../widgets/orbit_map_marker.dart';
import '../widgets/orbit_message_action_row.dart';
import '../widgets/orbit_person_avatar.dart';
import '../widgets/orbit_person_strip_item.dart';

abstract final class OrbitKeys {
  static const map = Key('orbit_map');
  static const sheet = Key('orbit_sheet');
  static const peopleList = Key('orbit_people_list');
  static const checkInButton = Key('orbit_check_in_button');
  static const expandedHeader = Key('orbit_expanded_header');
  static const giftGrid = Key('orbit_gift_grid');
  static const bottomNavigation = Key('orbit_bottom_navigation');

  static Key person(String id) => Key('orbit_person_$id');
  static Key marker(String id) => Key('orbit_marker_$id');
}

class OrbitScreen extends StatefulWidget {
  const OrbitScreen({
    required this.people,
    required this.gifts,
    required this.onCheckInPressed,
    required this.onPersonSelected,
    required this.onCameraPressed,
    required this.onSendPressed,
    required this.onGiftPressed,
    required this.onTabSelected,
    required this.onAddPressed,
    this.mapAssetPath = 'assets/orbit_map.png',
    super.key,
  });

  factory OrbitScreen.demo({
    ValueChanged<int>? onTabSelected,
    VoidCallback? onAddPressed,
  }) {
    return OrbitScreen(
      people: const <OrbitPersonData>[
        OrbitPersonData(
          id: 'suzie',
          name: 'Suzie',
          imagePath: 'assets/Emma.png',
          markerX: 0.22,
          markerY: 0.24,
          isNew: true,
        ),
        OrbitPersonData(
          id: 'daisy',
          name: 'Daisy',
          imagePath: 'assets/Mike.png',
          markerX: 0.66,
          markerY: 0.20,
        ),
        OrbitPersonData(
          id: 'sade',
          name: 'Sade',
          imagePath: 'assets/Sophia.png',
          markerX: 0.48,
          markerY: 0.43,
          isNew: true,
        ),
        OrbitPersonData(
          id: 'beth',
          name: 'Beth',
          imagePath: 'assets/Emma.png',
          markerX: 0.78,
          markerY: 0.52,
        ),
      ],
      gifts: const <OrbitGiftData>[
        OrbitGiftData(id: 'shoe', emoji: '👟', label: 'Shoe'),
        OrbitGiftData(id: 'money', emoji: '💸', label: 'Flying money'),
        OrbitGiftData(id: 'hand', emoji: '🤟', label: 'Hand gesture'),
        OrbitGiftData(id: 'donut', emoji: '🍩', label: 'Donut'),
        OrbitGiftData(id: 'dog', emoji: '🐶', label: 'Dog'),
        OrbitGiftData(id: 'pizza', emoji: '🍕', label: 'Pizza'),
        OrbitGiftData(id: 'pineapple', emoji: '🍍', label: 'Pineapple'),
        OrbitGiftData(id: 'sunglasses', emoji: '😎', label: 'Sunglasses face'),
        OrbitGiftData(id: 'smile', emoji: '😊', label: 'Smiling face'),
        OrbitGiftData(id: 'party', emoji: '🎉', label: 'Party popper'),
        OrbitGiftData(id: 'cat', emoji: '🐱', label: 'Cat'),
        OrbitGiftData(id: 'leaves', emoji: '🍃', label: 'Leaves'),
      ],
      onCheckInPressed: () {},
      onPersonSelected: (person) {},
      onCameraPressed: () {},
      onSendPressed: (person, message) {},
      onGiftPressed: (gift) {},
      onTabSelected: onTabSelected ?? (index) {},
      onAddPressed: onAddPressed ?? () {},
    );
  }

  final List<OrbitPersonData> people;
  final List<OrbitGiftData> gifts;
  final String mapAssetPath;
  final VoidCallback onCheckInPressed;
  final ValueChanged<OrbitPersonData> onPersonSelected;
  final VoidCallback onCameraPressed;
  final void Function(OrbitPersonData person, String message) onSendPressed;
  final ValueChanged<OrbitGiftData> onGiftPressed;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  @override
  State<OrbitScreen> createState() => _OrbitScreenState();
}

class _OrbitScreenState extends State<OrbitScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _messageController = TextEditingController();

  OrbitPersonData? _selectedPerson;
  bool _expandedContent = false;
  double _collapsedFraction = 0.30;
  double _expandedFraction = 0.82;

  @override
  void dispose() {
    _sheetController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavigationBar(
        key: OrbitKeys.bottomNavigation,
        selectedIndex: 1,
        onTabSelected: widget.onTabSelected,
        onAddPressed: widget.onAddPressed,
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _collapsedFraction = (206 / constraints.maxHeight)
                .clamp(0.28, 0.48)
                .toDouble();
            _expandedFraction = math
                .max(_collapsedFraction + 0.20, 0.82)
                .clamp(0.64, 0.90)
                .toDouble();

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _OrbitMapBackground(assetPath: widget.mapAssetPath),
                _OrbitMapMarkers(
                  people: widget.people,
                  onPersonPressed: _selectPerson,
                ),
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: _handleSheetNotification,
                  child: DraggableScrollableSheet(
                    key: OrbitKeys.sheet,
                    controller: _sheetController,
                    minChildSize: _collapsedFraction,
                    initialChildSize: _collapsedFraction,
                    maxChildSize: _expandedFraction,
                    builder: (context, scrollController) {
                      return _OrbitBottomPanel(
                        scrollController: scrollController,
                        expanded: _expandedContent && _selectedPerson != null,
                        people: widget.people,
                        gifts: widget.gifts,
                        selectedPerson: _selectedPerson,
                        messageController: _messageController,
                        onPersonPressed: _selectPerson,
                        onCheckInPressed: widget.onCheckInPressed,
                        onCameraPressed: widget.onCameraPressed,
                        onSendPressed: _sendMessage,
                        onGiftPressed: widget.onGiftPressed,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    if (!mounted) {
      return false;
    }

    final collapseThreshold = _collapsedFraction + 0.045;
    final expandThreshold = _collapsedFraction + 0.11;

    if (notification.extent <= collapseThreshold && _expandedContent) {
      setState(() => _expandedContent = false);
    } else if (_selectedPerson != null &&
        notification.extent >= expandThreshold &&
        !_expandedContent) {
      setState(() => _expandedContent = true);
    }
    return false;
  }

  void _selectPerson(OrbitPersonData person) {
    setState(() {
      _selectedPerson = person;
      _expandedContent = true;
      _messageController.clear();
    });
    widget.onPersonSelected(person);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sheetController.isAttached) {
        return;
      }
      _sheetController.animateTo(
        _expandedFraction,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _sendMessage() {
    final person = _selectedPerson;
    if (person == null) {
      return;
    }
    widget.onSendPressed(person, _messageController.text.trim());
  }
}

class _OrbitMapBackground extends StatelessWidget {
  const _OrbitMapBackground({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      key: OrbitKeys.map,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Color(0xFFE9EEF5),
            child: Center(
              child: Icon(
                Icons.map_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbitMapMarkers extends StatelessWidget {
  const _OrbitMapMarkers({required this.people, required this.onPersonPressed});

  final List<OrbitPersonData> people;
  final ValueChanged<OrbitPersonData> onPersonPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const markerSize = 46.0;
        final usableHeight = constraints.maxHeight * 0.68;

        return Stack(
          children: people
              .map((person) {
                final x = person.markerX.clamp(0.0, 1.0);
                final y = person.markerY.clamp(0.0, 1.0);
                final left =
                    x * math.max(0.0, constraints.maxWidth - markerSize);
                final top = y * math.max(0.0, usableHeight - markerSize);

                return Positioned(
                  key: OrbitKeys.marker(person.id),
                  left: left,
                  top: top,
                  child: OrbitMapMarker(
                    person: person,
                    onTap: () => onPersonPressed(person),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _OrbitBottomPanel extends StatelessWidget {
  const _OrbitBottomPanel({
    required this.scrollController,
    required this.expanded,
    required this.people,
    required this.gifts,
    required this.selectedPerson,
    required this.messageController,
    required this.onPersonPressed,
    required this.onCheckInPressed,
    required this.onCameraPressed,
    required this.onSendPressed,
    required this.onGiftPressed,
  });

  final ScrollController scrollController;
  final bool expanded;
  final List<OrbitPersonData> people;
  final List<OrbitGiftData> gifts;
  final OrbitPersonData? selectedPerson;
  final TextEditingController messageController;
  final ValueChanged<OrbitPersonData> onPersonPressed;
  final VoidCallback onCheckInPressed;
  final VoidCallback onCameraPressed;
  final VoidCallback onSendPressed;
  final ValueChanged<OrbitGiftData> onGiftPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: expanded && selectedPerson != null
              ? _ExpandedPanelContent(
                  key: ValueKey<String>('expanded-${selectedPerson!.id}'),
                  scrollController: scrollController,
                  person: selectedPerson!,
                  gifts: gifts,
                  messageController: messageController,
                  onCameraPressed: onCameraPressed,
                  onSendPressed: onSendPressed,
                  onGiftPressed: onGiftPressed,
                )
              : _CollapsedPanelContent(
                  key: const ValueKey<String>('collapsed'),
                  scrollController: scrollController,
                  people: people,
                  onPersonPressed: onPersonPressed,
                  onCheckInPressed: onCheckInPressed,
                ),
        ),
      ),
    );
  }
}

class _CollapsedPanelContent extends StatelessWidget {
  const _CollapsedPanelContent({
    required this.scrollController,
    required this.people,
    required this.onPersonPressed,
    required this.onCheckInPressed,
    super.key,
  });

  final ScrollController scrollController;
  final List<OrbitPersonData> people;
  final ValueChanged<OrbitPersonData> onPersonPressed;
  final VoidCallback onCheckInPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      children: <Widget>[
        if (people.isEmpty)
          const SizedBox(
            height: 104,
            child: Center(
              child: Text(
                'No people in this Orbit yet.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        else
          SizedBox(
            key: OrbitKeys.peopleList,
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final person = people[index];
                return KeyedSubtree(
                  key: OrbitKeys.person(person.id),
                  child: OrbitPersonStripItem(
                    person: person,
                    onTap: () => onPersonPressed(person),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          key: OrbitKeys.checkInButton,
          child: AppPrimaryButton(
            label: 'Check in',
            onPressed: onCheckInPressed,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ExpandedPanelContent extends StatelessWidget {
  const _ExpandedPanelContent({
    required this.scrollController,
    required this.person,
    required this.gifts,
    required this.messageController,
    required this.onCameraPressed,
    required this.onSendPressed,
    required this.onGiftPressed,
    super.key,
  });

  final ScrollController scrollController;
  final OrbitPersonData person;
  final List<OrbitGiftData> gifts;
  final TextEditingController messageController;
  final VoidCallback onCameraPressed;
  final VoidCallback onSendPressed;
  final ValueChanged<OrbitGiftData> onGiftPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
      children: <Widget>[
        Row(
          key: OrbitKeys.expandedHeader,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            OrbitPersonAvatar(person: person),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                person.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        OrbitMessageActionRow(
          personName: person.name,
          controller: messageController,
          onCameraPressed: onCameraPressed,
          onSendPressed: onSendPressed,
        ),
        const SizedBox(height: 10),
        KeyedSubtree(
          key: OrbitKeys.giftGrid,
          child: OrbitGiftGrid(items: gifts, onTap: onGiftPressed),
        ),
      ],
    );
  }
}
