import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../widgets/welcome_action_panel.dart';
import '../widgets/welcome_layout_metrics.dart';

abstract final class CreateCircleKeys {
  static const heading = Key('create_circle_heading');
  static const nameLabel = Key('create_circle_name_label');
  static const nameField = Key('create_circle_name_field');
  static const colorLabel = Key('create_circle_color_label');
  static const iconLabel = Key('create_circle_icon_label');
  static const nextButton = Key('create_circle_next_button');

  static Key color(int index) => Key('create_circle_color_$index');
  static Key icon(int index) => Key('create_circle_icon_$index');
}

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({required this.onNext, super.key});

  final VoidCallback onNext;

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  static const double _contentPadding = 15;
  static const double _headingBottomGap = 15;
  static const double _labelToControlGap = 8;
  static const double _sectionGap = 20;
  static const double _choiceLabelGap = 14;

  late final TextEditingController _nameController;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  static const List<_CircleColorOption> _colors = <_CircleColorOption>[
    _CircleColorOption(border: Color(0xFFF43F8E), fill: Color(0xFFEE8EB8)),
    _CircleColorOption(border: Color(0xFFC84ACD), fill: Color(0xFFDC7AD9)),
    _CircleColorOption(border: Color(0xFF16B393), fill: Color(0xFF67CFB1)),
    _CircleColorOption(border: Color(0xFF7C3AED), fill: Color(0xFFE9E4F6)),
    _CircleColorOption(border: Color(0xFF4B1DBE), fill: Color(0xFFC0B7E6)),
    _CircleColorOption(border: Color(0xFFFF5C00), fill: Color(0xFFF3AD83)),
    _CircleColorOption(border: Color(0xFF7C3AED), fill: Color(0xFFB084F4)),
  ];

  static const List<IconData> _icons = <IconData>[
    Icons.home_rounded,
    Icons.account_circle_outlined,
    Icons.star_border_rounded,
    Icons.music_note_rounded,
    Icons.location_on_outlined,
    Icons.wb_sunny_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Best Friends');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              final buttonHorizontalPadding =
                  WelcomeLayoutMetrics.horizontalPadding(constraints.maxWidth);
              final contentBottomInset =
                  WelcomeLayoutMetrics.contentBottomInset(context);

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    bottom: contentBottomInset,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        _contentPadding,
                        compact ? 12 : 52,
                        _contentPadding,
                        16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: compact
                              ? 0
                              : constraints.maxHeight - contentBottomInset - 68,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Create Your\nFirst Circle',
                              key: CreateCircleKeys.heading,
                              textAlign: TextAlign.center,
                              style: AppTypography.largeHeading.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: _headingBottomGap),
                            const Text(
                              'Circle Name:',
                              key: CreateCircleKeys.nameLabel,
                              style: _CreateCircleStyles.label,
                            ),
                            const SizedBox(height: _labelToControlGap),
                            _CircleNameField(controller: _nameController),
                            const SizedBox(height: _sectionGap),
                            const Text(
                              'Choose A Color:',
                              key: CreateCircleKeys.colorLabel,
                              style: _CreateCircleStyles.label,
                            ),
                            const SizedBox(height: _choiceLabelGap),
                            _ColorPicker(
                              options: _colors,
                              selectedIndex: _selectedColorIndex,
                              onSelected: (index) {
                                setState(() => _selectedColorIndex = index);
                              },
                            ),
                            const SizedBox(height: _sectionGap),
                            const Text(
                              'Choose A Icon:',
                              key: CreateCircleKeys.iconLabel,
                              style: _CreateCircleStyles.label,
                            ),
                            const SizedBox(height: _choiceLabelGap),
                            _IconPicker(
                              icons: _icons,
                              selectedIndex: _selectedIconIndex,
                              onSelected: (index) {
                                setState(() => _selectedIconIndex = index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: buttonHorizontalPadding,
                    right: buttonHorizontalPadding,
                    bottom: WelcomeLayoutMetrics.bottomSpacing,
                    child: Center(
                      child: WelcomeActionPanel(
                        primaryKey: CreateCircleKeys.nextButton,
                        primaryLabel: 'Next',
                        onPrimaryPressed: widget.onNext,
                        reserveSecondarySlot: true,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

abstract final class _CreateCircleStyles {
  static const TextStyle label = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );

  static const TextStyle input = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  );
}

class _CircleNameField extends StatelessWidget {
  const _CircleNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: CreateCircleKeys.nameField,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset.zero,
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: _CreateCircleStyles.input,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.only(left: 15, top: 14, bottom: 14),
          suffixIconConstraints: BoxConstraints(minWidth: 50, minHeight: 46),
          suffixIcon: Icon(
            Icons.favorite_rounded,
            color: Color(0xFFE00000),
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_CircleColorOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(options.length, (index) {
        final option = options[index];
        final selected = selectedIndex == index;

        return Semantics(
          selected: selected,
          button: true,
          label: 'Circle color ${index + 1}',
          child: InkResponse(
            key: CreateCircleKeys.color(index),
            onTap: () => onSelected(index),
            radius: 22,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              scale: selected ? 1 : 0.94,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: option.fill,
                  border: Border.all(color: option.border, width: 2),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(icons.length, (index) {
        final selected = selectedIndex == index;

        return Semantics(
          selected: selected,
          button: true,
          label: 'Circle icon ${index + 1}',
          child: Material(
            key: CreateCircleKeys.icon(index),
            color: selected ? const Color(0x1A7C3AED) : AppColors.white,
            borderRadius: BorderRadius.circular(6.67),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(index),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.67),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset.zero,
                      blurRadius: 2.67,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  icons[index],
                  size: 25,
                  color: selected ? const Color(0xFF7C3AED) : Colors.black,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CircleColorOption {
  const _CircleColorOption({required this.border, required this.fill});

  final Color border;
  final Color fill;
}
