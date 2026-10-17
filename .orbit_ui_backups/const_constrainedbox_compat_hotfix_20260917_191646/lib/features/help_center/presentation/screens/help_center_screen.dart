import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../../core/widgets/app_action_row.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../domain/models/help_center_item.dart';
import 'help_topic_screen.dart';

enum HelpCenterViewState { loading, loaded, error }

abstract final class HelpCenterKeys {
  static const scrollView = Key('help_center_scroll_view');
  static const backButton = Key('help_center_back_button');
  static const title = Key('help_center_title');
  static const searchField = Key('help_center_search_field');
  static const searchInput = Key('help_center_search_input');
  static const emptyState = Key('help_center_empty_state');
  static const loadingState = Key('help_center_loading_state');
  static const errorState = Key('help_center_error_state');

  static Key item(String id) => Key('help_center_item_$id');
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({
    this.items = HelpCenterItem.demoItems,
    this.viewState = HelpCenterViewState.loaded,
    this.errorMessage = 'Unable to load help topics.',
    this.onRetry,
    this.onItemPressed,
    this.onBack,
    super.key,
  });

  final List<HelpCenterItem> items;
  final HelpCenterViewState viewState;
  final String errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<HelpCenterItem>? onItemPressed;
  final VoidCallback? onBack;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const double _screenPadding = 20;
  static const double _topPadding = 20;
  static const double _headerGap = 20;
  static const double _searchToListGap = 16;
  static const double _itemGap = 10;
  static const double _maxContentWidth = 600;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            key: HelpCenterKeys.scrollView,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _screenPadding,
                  _topPadding,
                  _screenPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: AppScreenHeader(
                        title: 'Help Center',
                        onBack: widget.onBack,
                        backButtonKey: HelpCenterKeys.backButton,
                        titleKey: HelpCenterKeys.title,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: _headerGap)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _screenPadding),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: _HelpSearchField(
                        controller: _searchController,
                        onChanged: (value) {
                          if (_query == value) {
                            return;
                          }
                          setState(() => _query = value);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: _searchToListGap),
              ),
              ..._buildContentSlivers(filteredItems),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(List<HelpCenterItem> filteredItems) {
    switch (widget.viewState) {
      case HelpCenterViewState.loading:
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _screenPadding),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: const _HelpLoadingState(),
                ),
              ),
            ),
          ),
        ];
      case HelpCenterViewState.error:
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _screenPadding),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: _HelpErrorState(
                    message: widget.errorMessage,
                    onRetry: widget.onRetry,
                  ),
                ),
              ),
            ),
          ),
        ];
      case HelpCenterViewState.loaded:
        if (filteredItems.isEmpty) {
          return <Widget>[
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: _screenPadding),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: _maxContentWidth),
                    child: _HelpEmptyState(),
                  ),
                ),
              ),
            ),
          ];
        }

        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _screenPadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index.isOdd) {
                  return const SizedBox(height: _itemGap);
                }
                final item = filteredItems[index ~/ 2];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _maxContentWidth,
                    ),
                    child: _HelpOptionTile(
                      item: item,
                      onTap: () => _openItem(item),
                    ),
                  ),
                );
              }, childCount: (filteredItems.length * 2) - 1),
            ),
          ),
        ];
    }
  }

  List<HelpCenterItem> _filteredItems() {
    if (widget.viewState != HelpCenterViewState.loaded) {
      return const <HelpCenterItem>[];
    }

    final query = _normalize(_query);
    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items
        .where((item) {
          if (_normalize(item.title).contains(query)) {
            return true;
          }
          return item.keywords.any(
            (keyword) => _normalize(keyword).contains(query),
          );
        })
        .toList(growable: false);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _openItem(HelpCenterItem item) {
    FocusManager.instance.primaryFocus?.unfocus();

    if (widget.onItemPressed != null) {
      widget.onItemPressed!(item);
      return;
    }

    final destination = switch (item.destination) {
      HelpCenterDestination.contactSupport => const ContactSupportScreen(),
      HelpCenterDestination.privacyHelp => const PrivacyHelpScreen(),
      HelpCenterDestination.safetyHelp => const SafetyHelpScreen(),
      HelpCenterDestination.faq => const FAQScreen(),
    };

    Navigator.of(context).push<void>(
      AppFadeSlidePageRoute<void>(builder: (context) => destination),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: HelpCenterKeys.searchField,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0A000000), width: 1),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF96A0B3)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: HelpCenterKeys.searchInput,
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w400,
                color: Color(0xFF0F1724),
              ),
              decoration: const InputDecoration.collapsed(
                hintText: 'Search by name or Phone',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF96A0B3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpOptionTile extends StatelessWidget {
  const _HelpOptionTile({required this.item, required this.onTap});

  final HelpCenterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: AppActionRow(
          containerKey: HelpCenterKeys.item(item.id),
          leadingIcon: Icons.circle,
          iconBackgroundColor: Colors.transparent,
          leadingIconColor: Colors.transparent,
          showLeading: false,
          title: item.title,
          onTap: onTap,
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _HelpLoadingState extends StatelessWidget {
  const _HelpLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: HelpCenterKeys.loadingState,
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: Alignment.center,
      child: const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _HelpEmptyState extends StatelessWidget {
  const _HelpEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: HelpCenterKeys.emptyState,
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: const Text(
        'No help topics found',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _HelpErrorState extends StatelessWidget {
  const _HelpErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: HelpCenterKeys.errorState,
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                overlayColor: Colors.transparent,
              ),
              child: const Text(
                'Try again',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
