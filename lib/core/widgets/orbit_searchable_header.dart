import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';
import 'app_circular_icon_button.dart';

class OrbitSearchController extends ChangeNotifier {
  OrbitSearchController();

  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  bool _isSearching = false;

  bool get isSearching => _isSearching;
  String get query => textController.text;

  void open() {
    if (_isSearching) {
      focusNode.requestFocus();
      return;
    }

    _isSearching = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  void close({bool clear = true}) {
    if (clear) {
      textController.clear();
    }
    focusNode.unfocus();

    if (!_isSearching) {
      return;
    }

    _isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class OrbitSearchableHeader extends StatelessWidget {
  const OrbitSearchableHeader({
    required this.title,
    required this.placeholder,
    required this.controller,
    required this.onQueryChanged,
    this.onBack,
    this.onSearchOpened,
    this.onSearchPressed,
    this.searchSemanticLabel,
    this.showBack = true,
    this.compactTitle = false,
    this.trailingActions = const <Widget>[],
    this.titleKey,
    this.searchButtonKey,
    this.closeButtonKey,
    super.key,
  });

  static const double height = 44;

  final String title;
  final String placeholder;
  final OrbitSearchController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onBack;
  final VoidCallback? onSearchOpened;
  /// Override navigation only when a screen uses the search icon as a route.
  /// Without an override the existing inline search behavior is preserved.
  final VoidCallback? onSearchPressed;
  final String? searchSemanticLabel;
  final bool showBack;
  /// Reuses the compact 16pt title and 30px back control of AppScreenHeader.
  /// All compact header icon actions use the same 30px circular button as Back.
  final bool compactTitle;
  final List<Widget> trailingActions;
  final Key? titleKey;
  final Key? searchButtonKey;
  final Key? closeButtonKey;

  ThemeData _noFlashTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }

  void _closeSearch() {
    controller.close();
    onQueryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return PopScope<Object?>(
          canPop: !controller.isSearching,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && controller.isSearching) {
              _closeSearch();
            }
          },
          child: SizedBox(
            height: height,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                );
              },
              child: controller.isSearching
                  ? _buildSearchMode(context)
                  : _buildNormalMode(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNormalMode(BuildContext context) {
    return Row(
      key: const ValueKey<String>('orbit_search_header_normal'),
      children: <Widget>[
        if (showBack) ...<Widget>[
          Theme(
            data: _noFlashTheme(context),
            child: AppCircularIconButton(
              semanticLabel: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icons.chevron_left_rounded,
              iconSize: 24,
              iconColor: Colors.black,
              size: compactTitle ? 30 : 40,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: compactTitle ? 16 : 24,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F1724),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Theme(
          data: _noFlashTheme(context),
          child: AppCircularIconButton(
            key: searchButtonKey,
            semanticLabel: searchSemanticLabel ?? 'Search $title',
            onPressed: onSearchPressed ?? () {
              onSearchOpened?.call();
              controller.open();
            },
            icon: Icons.search_rounded,
            iconSize: compactTitle ? 24 : 20,
            iconColor: compactTitle ? Colors.black : const Color(0xFF7C3AED),
            size: compactTitle ? 30 : 40,
          ),
        ),
        for (final action in trailingActions) ...<Widget>[
          SizedBox(width: compactTitle ? 10 : 6),
          action,
        ],
      ],
    );
  }

  Widget _buildSearchMode(BuildContext context) {
    return Row(
      key: const ValueKey<String>('orbit_search_header_search'),
      children: <Widget>[
        if (showBack) ...<Widget>[
          Theme(
            data: _noFlashTheme(context),
            child: AppCircularIconButton(
              semanticLabel: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icons.chevron_left_rounded,
              iconSize: 24,
              iconColor: Colors.black,
              size: compactTitle ? 30 : 40,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OrbitSearchField(
            controller: controller.textController,
            focusNode: controller.focusNode,
            placeholder: placeholder,
            onChanged: onQueryChanged,
          ),
        ),
        const SizedBox(width: 8),
        Theme(
          data: _noFlashTheme(context),
          child: AppCircularIconButton(
            key: closeButtonKey,
            semanticLabel: 'Close search',
            onPressed: _closeSearch,
            icon: Icons.close,
            iconSize: compactTitle ? 24 : 20,
            iconColor: compactTitle ? Colors.black : const Color(0xFF0F1724),
            size: compactTitle ? 30 : 40,
          ),
        ),
      ],
    );
  }
}

class OrbitSearchField extends StatelessWidget {
  const OrbitSearchField({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: const Color(0xFF7C3AED),
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
          color: Color(0xFF0F1724),
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: placeholder,
          hintStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: Color(0xFF94A3B8),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          contentPadding: const EdgeInsets.fromLTRB(2, 10, 14, 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x0A000000)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0x337C3AED), width: 1.2),
          ),
        ),
      ),
    );
  }
}
