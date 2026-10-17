import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppOtpInput extends StatefulWidget {
  const AppOtpInput({
    required this.onChanged,
    this.length = 6,
    this.initialCode = '',
    this.enabled = true,
    this.autofocus = false,
    super.key,
  }) : assert(length > 0);

  static const double referenceBoxWidth = 40;
  static const double referenceBoxHeight = 39;
  static const double minimumGap = 4;
  static const double radius = 20;

  final int length;
  final String initialCode;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  State<AppOtpInput> createState() => _AppOtpInputState();
}

class _AppOtpInputState extends State<AppOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (index) => TextEditingController(),
    );
    _focusNodes = List<FocusNode>.generate(
      widget.length,
      (index) => FocusNode(debugLabel: 'otp_digit_${index + 1}'),
    );
    _applyCode(widget.initialCode, notify: false);
  }

  @override
  void didUpdateWidget(covariant AppOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCode != widget.initialCode) {
      _applyCode(widget.initialCode, notify: false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((controller) => controller.text).join();

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  void _applyCode(String value, {required bool notify}) {
    final digits = _digitsOnly(value);
    for (var index = 0; index < widget.length; index++) {
      final text = index < digits.length ? digits[index] : '';
      _setControllerText(index, text);
    }
    if (notify) {
      widget.onChanged(_code);
    }
  }

  void _setControllerText(int index, String text) {
    _controllers[index].value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleChanged(int index, String rawValue) {
    final digits = _digitsOnly(rawValue);

    if (digits.isEmpty) {
      _setControllerText(index, '');
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].selection = TextSelection.collapsed(
          offset: _controllers[index - 1].text.length,
        );
      }
      widget.onChanged(_code);
      return;
    }

    if (digits.length == 1) {
      _setControllerText(index, digits);
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
      widget.onChanged(_code);
      return;
    }

    var targetIndex = index;
    for (final digit in digits.split('')) {
      if (targetIndex >= widget.length) {
        break;
      }
      _setControllerText(targetIndex, digit);
      targetIndex++;
    }

    if (targetIndex < widget.length) {
      _focusNodes[targetIndex].requestFocus();
    } else {
      _focusNodes[widget.length - 1].requestFocus();
    }
    widget.onChanged(_code);
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection.collapsed(
        offset: _controllers[index - 1].text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final minimumGapTotal = AppOtpInput.minimumGap * (widget.length - 1);
        final responsiveBoxWidth = widget.length > 0
            ? ((availableWidth - minimumGapTotal) / widget.length)
                  .clamp(0.0, AppOtpInput.referenceBoxWidth)
                  .toDouble()
            : 0.0;
        final usedWidth = responsiveBoxWidth * widget.length;
        final gap = widget.length > 1
            ? ((availableWidth - usedWidth) / (widget.length - 1))
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;
        final boxWidth = responsiveBoxWidth;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var index = 0; index < widget.length; index++) ...<Widget>[
              SizedBox(
                key: ValueKey<String>('otp_box_${index + 1}'),
                width: boxWidth,
                height: AppOtpInput.referenceBoxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppOtpInput.radius),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x1A000000),
                        offset: Offset.zero,
                        blurRadius: 2,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: (node, event) => _handleKeyEvent(index, event),
                    child: TextField(
                      key: ValueKey<String>('otp_field_${index + 1}'),
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      autofocus: widget.autofocus && index == 0,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: index == widget.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F1724),
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: '${index + 1}',
                        hintStyle: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) => _handleChanged(index, value),
                    ),
                  ),
                ),
              ),
              if (index < widget.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}
