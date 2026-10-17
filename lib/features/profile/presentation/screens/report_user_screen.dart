import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../domain/models/report_user_models.dart';

abstract final class ReportUserKeys {
  static const scrollView = Key('report_user_scroll_view');
  static const backButton = Key('report_user_back_button');
  static const title = Key('report_user_title');
  static const card = Key('report_user_card');
  static const submitButton = Key('report_user_submit_button');

  static Key reasonRow(ReportReason reason) =>
      Key('report_reason_${reason.name}_row');
  static Key reasonIndicator(ReportReason reason) =>
      Key('report_reason_${reason.name}_indicator');
}

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({
    required this.args,
    this.initialReason,
    this.reasons,
    this.onBack,
    this.onSubmit,
    this.onSubmitted,
    super.key,
  });

  factory ReportUserScreen.demo() {
    return const ReportUserScreen(
      args: ReportUserArgs(userId: 'mike-smith', displayName: 'Mike Smith'),
      initialReason: ReportReason.other,
    );
  }

  factory ReportUserScreen.forUser({
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) {
    return ReportUserScreen(
      args: ReportUserArgs(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      ),
    );
  }

  final ReportUserArgs args;
  final ReportReason? initialReason;
  final List<ReportReason>? reasons;
  final VoidCallback? onBack;
  final Future<void> Function(ReportRequest request)? onSubmit;
  final ValueChanged<ReportRequest>? onSubmitted;

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  static const Color _background = Color(0xFFF9F9F9);
  static const Color _dark = Color(0xFF0F1724);
  static const double _screenPadding = 20;
  static const double _cardRadius = 30;
  static const double _cardMaxWidth = 335;
  static const double _sectionGap = 25;
  static const double _maxContentWidth = 430;

  ReportReason? _selectedReason;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.initialReason;
  }

  @override
  void didUpdateWidget(covariant ReportUserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.args.userId != widget.args.userId ||
        oldWidget.initialReason != widget.initialReason) {
      _selectedReason = widget.initialReason;
      _isSubmitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _screenPadding,
                    _screenPadding,
                    _screenPadding,
                    0,
                  ),
                  child: AppScreenHeader(
                    title: 'Report User',
                    backButtonKey: ReportUserKeys.backButton,
                    titleKey: ReportUserKeys.title,
                    onBack: widget.onBack,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final minBodyHeight = constraints.maxHeight > 40
                          ? constraints.maxHeight - 40
                          : 0.0;
                      return SingleChildScrollView(
                        key: ReportUserKeys.scrollView,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(_screenPadding),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: minBodyHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _cardMaxWidth,
                              ),
                              child: _buildReportCard(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    final reasons = widget.reasons ?? ReportReason.values;
    return Container(
      key: ReportUserKeys.card,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x127C3AED),
            offset: Offset(0, 4),
            blurRadius: 32,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Why are you reporting ${widget.args.displayName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 20,
                height: 1.19,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ),
          const SizedBox(height: _sectionGap),
          _ReportReasonGroup(
            reasons: reasons,
            selectedReason: _selectedReason,
            onChanged: _handleReasonChanged,
          ),
          const SizedBox(height: _sectionGap),
          IgnorePointer(
            ignoring: _isSubmitting,
            child: KeyedSubtree(
              key: ReportUserKeys.submitButton,
              child: AppPrimaryButton(
                label: _isSubmitting ? 'Submitting...' : 'Submit Report',
                onPressed: _handleSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReasonChanged(ReportReason reason) {
    if (_isSubmitting || _selectedReason == reason) {
      return;
    }
    setState(() => _selectedReason = reason);
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    final reason = _selectedReason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a reason before submitting.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final request = ReportRequest(
      reportedUserId: widget.args.userId,
      reason: reason,
    );

    setState(() => _isSubmitting = true);
    try {
      final submit = widget.onSubmit;
      if (submit != null) {
        await submit(request);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (!mounted) {
        return;
      }

      widget.onSubmitted?.call(request);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit the report. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ReportReasonGroup extends StatelessWidget {
  const _ReportReasonGroup({
    required this.reasons,
    required this.selectedReason,
    required this.onChanged,
  });

  final List<ReportReason> reasons;
  final ReportReason? selectedReason;
  final ValueChanged<ReportReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x14000000)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var index = 0; index < reasons.length; index++) ...<Widget>[
              _ReportReasonRow(
                reason: reasons[index],
                selected: reasons[index] == selectedReason,
                onTap: () => onChanged(reasons[index]),
              ),
              if (index != reasons.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x14000000),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportReasonRow extends StatelessWidget {
  const _ReportReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: reason.label,
      child: GestureDetector(
        key: ReportUserKeys.reasonRow(reason),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    reason.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? const Color(0xFF0F1724)
                          : const Color(0xFF8B95A8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _OrbitRadioIndicator(
                  key: ReportUserKeys.reasonIndicator(reason),
                  selected: selected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitRadioIndicator extends StatelessWidget {
  const _OrbitRadioIndicator({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
              )
            : null,
        color: selected ? null : Colors.white,
        border: selected
            ? null
            : Border.all(color: const Color(0x14000000), width: 2),
      ),
      child: selected
          ? const Center(
              child: SizedBox.square(
                dimension: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
