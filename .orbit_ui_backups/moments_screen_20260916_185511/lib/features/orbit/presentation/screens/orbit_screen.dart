import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
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
  static const sheetHandle = Key('orbit_sheet_handle');
  static const timeLabel = Key('orbit_time_label');
  static const liveBadge = Key('orbit_live_badge');
  static const bestFriendsChip = Key('orbit_best_friends_chip');

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
          markerX: 0.23,
          markerY: 0.22,
          isNew: true,
        ),
        OrbitPersonData(
          id: 'daisy',
          name: 'Daisy',
          imagePath: 'assets/Mike.png',
          markerX: 0.64,
          markerY: 0.18,
          isNew: true,
        ),
        OrbitPersonData(
          id: 'saqe',
          name: 'Saqe',
          imagePath: 'assets/Sophia.png',
          markerX: 0.48,
          markerY: 0.42,
          isNew: true,
        ),
        OrbitPersonData(
          id: 'beth',
          name: 'Beth',
          imagePath: 'assets/Emma.png',
          markerX: 0.78,
          markerY: 0.51,
          isNew: true,
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
  double _expandedTargetFraction = 0.56;
  double _maxExpandedFraction = 0.86;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _messageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNavigationBar(
          key: OrbitKeys.bottomNavigation,
          selectedIndex: 1,
          onTabSelected: widget.onTabSelected,
          onAddPressed: widget.onAddPressed,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            _collapsedFraction = (220 / constraints.maxHeight)
                .clamp(0.27, 0.42)
                .toDouble();
            _expandedTargetFraction = (470 / constraints.maxHeight)
                .clamp(0.54, 0.78)
                .toDouble();
            _maxExpandedFraction = math
                .max(_expandedTargetFraction + 0.10, 0.82)
                .clamp(0.82, 0.92)
                .toDouble();

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _OrbitMapBackground(assetPath: widget.mapAssetPath),
                _OrbitMapMarkers(
                  people: widget.people,
                  onPersonPressed: _selectPerson,
                ),
                const _OrbitMapHud(),
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: _handleSheetNotification,
                  child: DraggableScrollableSheet(
                    key: OrbitKeys.sheet,
                    controller: _sheetController,
                    minChildSize: _collapsedFraction,
                    initialChildSize: _collapsedFraction,
                    maxChildSize: _maxExpandedFraction,
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

    // Dragging the sheet must never select or reopen a person automatically.
    // Expanded person content is entered only through an explicit person tap.
    // A downward drag may collapse an already-open person panel back to the
    // compact people list.
    if (notification.extent <= collapseThreshold && _expandedContent) {
      setState(() => _expandedContent = false);
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
        _expandedTargetFraction,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox.expand(
          key: OrbitKeys.map,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                assetPath,
                width: constraints.maxWidth,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: const ColoredBox(
                      color: Color(0xFFE9EEF5),
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbitMapHud extends StatelessWidget {
  const _OrbitMapHud();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: <Widget>[
                const Positioned(
                  top: 36,
                  left: 15,
                  child: Text(
                    '9:41',
                    key: OrbitKeys.timeLabel,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const Positioned(top: 34, right: 15, child: _LiveBadge()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        key: OrbitKeys.liveBadge,
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.circle, size: 11, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'LIVE',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
        final usableHeight = constraints.maxHeight * 0.64;

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

class _OrbitSheetHandle extends StatelessWidget {
  const _OrbitSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: OrbitKeys.sheetHandle,
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFECEFF5),
          borderRadius: BorderRadius.circular(999),
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
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
      children: <Widget>[
        const _OrbitSheetHandle(),
        const SizedBox(height: 12),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final visibleCount = math.min(people.length, 4);
                final distributedWidth = visibleCount == 0
                    ? 82.0
                    : (constraints.maxWidth - (gap * (visibleCount - 1))) /
                          visibleCount;
                final itemWidth = people.length <= 4
                    ? math.max(82.0, distributedWidth)
                    : 82.0;

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: people.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: gap),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return KeyedSubtree(
                      key: OrbitKeys.person(person.id),
                      child: OrbitPersonStripItem(
                        person: person,
                        width: itemWidth,
                        onTap: () => onPersonPressed(person),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: KeyedSubtree(
            key: OrbitKeys.checkInButton,
            child: _CheckInButton(onPressed: onCheckInPressed),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x337C5CFC),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150, minHeight: 49),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 13, 28, 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  Icon(
                    Icons.location_on_outlined,
                    size: 21,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Check in',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 24),
      children: <Widget>[
        const _OrbitSheetHandle(),
        const SizedBox(height: 14),
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
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
        const SizedBox(height: 13),
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
