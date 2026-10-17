import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    this.label,
    this.labelKey,
    this.labelTrailing,
    this.fieldKey,
    this.hintText,
    this.initialValue,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.enabled = true,
    this.onChanged,
    super.key,
  }) : assert(
         controller == null || initialValue == null,
         'Use either controller or initialValue, not both.',
       );

  static const double referenceHeight = 49;
  static const double radius = 30;
  static const double horizontalContentPadding = 14;
  static const double labelToFieldGap = 8;

  static const Color labelColor = Color(0xFF0F1724);
  static const Color inputColor = Color(0xFF0F1724);
  static const Color fieldShadowColor = Color(0x1A000000);

  final String? label;
  final Key? labelKey;
  final Widget? labelTrailing;
  final Key? fieldKey;
  final String? hintText;
  final String? initialValue;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final GlobalKey<FormFieldState<String>> _formFieldKey =
      GlobalKey<FormFieldState<String>>();

  TextEditingController? _internalController;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController(text: widget.initialValue);
    }
    _effectiveController.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldController = oldWidget.controller ?? _internalController;
      oldController?.removeListener(_handleControllerChanged);

      if (oldWidget.controller == null) {
        _internalController?.dispose();
        _internalController = null;
      }

      if (widget.controller == null) {
        _internalController = TextEditingController(text: widget.initialValue);
      }
      _effectiveController.addListener(_handleControllerChanged);
    }
  }

  void _handleControllerChanged() {
    final value = _effectiveController.text;
    _formFieldKey.currentState?.didChange(value);
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleControllerChanged);
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabelRow = widget.label != null || widget.labelTrailing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasLabelRow) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!,
                    key: widget.labelKey,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: AppTextField.labelColor,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (widget.labelTrailing != null) widget.labelTrailing!,
            ],
          ),
          const SizedBox(height: AppTextField.labelToFieldGap),
        ],
        FormField<String>(
          key: _formFieldKey,
          initialValue: _effectiveController.text,
          validator: widget.validator,
          enabled: widget.enabled,
          builder: (field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  key: widget.fieldKey,
                  height: AppTextField.referenceHeight,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppTextField.radius),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: AppTextField.fieldShadowColor,
                        offset: Offset.zero,
                        blurRadius: 2,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _effectiveController,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textAlignVertical: TextAlignVertical.center,
                    maxLines: 1,
                    strutStyle: const StrutStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      height: 1,
                      forceStrutHeight: true,
                    ),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w400,
                      color: AppTextField.inputColor,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTextField.horizontalContentPadding,
                      ),
                      prefixIcon: widget.prefixIcon,
                      suffixIcon: widget.suffixIcon,
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: AppTextField.referenceHeight,
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: AppTextField.referenceHeight,
                      ),
                    ),
                  ),
                ),
                if (field.hasError) ...<Widget>[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTextField.horizontalContentPadding,
                    ),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
