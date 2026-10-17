import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/ping_models.dart';
import '../widgets/ping_option_card.dart';

abstract final class PingKeys {
  static const scroll = Key('ping_scroll');
  static const backButton = Key('ping_back_button');
  static const infoButton = Key('ping_info_button');
  static const customMessage = Key('ping_custom_message');
  static const customField = Key('ping_custom_field');
  static const customSend = Key('ping_custom_send');

  static Key option(String id) => Key('ping_option_$id');
}

typedef PingSender = FutureOr<void> Function(PingSubmission submission);

class PingScreen extends StatefulWidget {
  const PingScreen({
    required this.options,
    this.onSendPing,
    this.onInfoPressed,
    this.recipientOrCircleId,
    super.key,
  });

  factory PingScreen.demo({
    PingSender? onSendPing,
    VoidCallback? onInfoPressed,
    String? recipientOrCircleId,
  }) {
    return PingScreen(
      options: const <PingOption>[
        PingOption(
          id: 'hello',
          emoji: '\u{1F44B}',
          title: 'Hello',
          backgroundColor: Color(0xFFFFF3E8),
          foregroundColor: Color(0xFFE8A030),
        ),
        PingOption(
          id: 'where',
          emoji: '\u{1F4CD}',
          title: 'Where are you?',
          backgroundColor: Color(0xFFEFECFF),
          foregroundColor: Color(0xFF6656D9),
        ),
        PingOption(
          id: 'on-my-way',
          emoji: '\u{1F697}',
          title: "I'm on my way",
          backgroundColor: Color(0xFFE5F7F1),
          foregroundColor: Color(0xFF18A47E),
        ),
        PingOption(
          id: 'right-there',
          emoji: '\u{23F0}',
          title: 'Be right there',
          backgroundColor: Color(0xFFECF1FF),
          foregroundColor: Color(0xFF4978E8),
        ),
        PingOption(
          id: 'love',
          emoji: '\u{2764}\u{FE0F}',
          title: 'Love you',
          backgroundColor: Color(0xFFFFE9EB),
          foregroundColor: Color(0xFFEF4851),
        ),
        PingOption(
          id: 'call',
          emoji: '\u{26A0}\u{FE0F}',
          title: 'Call me',
          backgroundColor: Color(0xFFFFF4D9),
          foregroundColor: Color(0xFFD58A00),
        ),
      ],
      onSendPing: onSendPing,
      onInfoPressed: onInfoPressed,
      recipientOrCircleId: recipientOrCircleId,
    );
  }

  final List<PingOption> options;
  final PingSender? onSendPing;
  final VoidCallback? onInfoPressed;
  final String? recipientOrCircleId;

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  static const double _horizontalPadding = 20;
  String? _sendingId;

  Future<void> _send(PingOption option) async {
    if (_sendingId != null) return;
    setState(() => _sendingId = option.id);

    final submission = PingSubmission(
      type: option.id,
      message: option.title,
      sentAt: DateTime.now(),
      recipientOrCircleId: widget.recipientOrCircleId,
    );

    try {
      await widget.onSendPing?.call(submission);
      if (!mounted) return;
      if (widget.onSendPing == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 900),
              content: Text('${option.title} ping sent'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  void _showInfo() {
    if (widget.onInfoPressed != null) {
      widget.onInfoPressed!();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'About Ping',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Send a quick predefined message or write your own custom Ping. Recipient and delivery data can be connected to the backend without changing this screen.',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A85A8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomMessage() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
            ),
            child: SafeArea(
              top: false,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Custom Message',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      fieldKey: PingKeys.customField,
                      controller: controller,
                      hintText: 'Type your Ping...',
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a message';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: PingKeys.customSend,
                      child: AppPrimaryButton(
                        label: 'Send Ping',
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false))
                            return;
                          final message = controller.text.trim();
                          Navigator.of(sheetContext).pop();
                          await _send(
                            PingOption(
                              id: 'custom',
                              emoji: '',
                              title: message,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.black,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            key: PingKeys.scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: <Widget>[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (widget.options.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
                  sliver: SliverToBoxAdapter(child: _EmptyPingState()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) return const SizedBox(height: 12);
                      final option = widget.options[index ~/ 2];
                      return PingOptionCard(
                        key: PingKeys.option(option.id),
                        option: option,
                        enabled: _sendingId == null,
                        onTap: () => _send(option),
                      );
                    }, childCount: widget.options.length * 2 - 1),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                sliver: SliverToBoxAdapter(child: _buildCustomMessage()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          AppCircularIconButton(
            key: PingKeys.backButton,
            semanticLabel: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icons.chevron_left_rounded,
            size: 40,
            iconSize: 28,
            iconColor: const Color(0xFF1A1A2E),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Ping',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AppCircularIconButton(
            key: PingKeys.infoButton,
            semanticLabel: 'Ping information',
            onPressed: _showInfo,
            icon: Icons.info_outline_rounded,
            size: 40,
            iconSize: 23,
            iconColor: const Color(0xFF1A1A2E),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomMessage() {
    return Semantics(
      button: true,
      label: 'Custom Message',
      child: GestureDetector(
        key: PingKeys.customMessage,
        behavior: HitTestBehavior.opaque,
        onTap: _openCustomMessage,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E0F5)),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.edit_outlined, size: 22, color: Color(0xFF8A85A8)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Custom Message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A85A8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFF8A85A8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPingState extends StatelessWidget {
  const _EmptyPingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No quick Pings are available right now. You can still send a custom message.',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          height: 1.4,
          color: Color(0xFF8A85A8),
        ),
      ),
    );
  }
}
