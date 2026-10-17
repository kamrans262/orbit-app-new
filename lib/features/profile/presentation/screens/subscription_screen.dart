import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';

/// Orbit subscription UI. Displayed tiers and USD prices are product-scope
/// examples, not a live App Store / Google Play catalog or an entitlement check.
abstract final class SubscriptionKeys {
  static const title = Key('subscription_title');
  static const back = Key('subscription_back');
  static const scrollView = Key('subscription_scroll_view');
  static const purchaseButton = Key('subscription_purchase_button');
  static const restoreButton = Key('subscription_restore_button');
  static const currentPlan = Key('subscription_current_plan');
  static Key plan(String id) => Key('subscription_plan_$id');
}

enum OrbitSubscriptionTier { free, lite, plus }

extension OrbitSubscriptionTierDetails on OrbitSubscriptionTier {
  String get label => switch (this) {
    OrbitSubscriptionTier.free => 'Free',
    OrbitSubscriptionTier.lite => 'Orbit Lite',
    OrbitSubscriptionTier.plus => 'Orbit Plus',
  };

  String get price => switch (this) {
    OrbitSubscriptionTier.free => r'$0',
    OrbitSubscriptionTier.lite => r'$1.99',
    OrbitSubscriptionTier.plus => r'$4.99',
  };

  String get details => switch (this) {
    OrbitSubscriptionTier.free => 'Core Orbit essentials',
    OrbitSubscriptionTier.lite => 'More history, fewer distractions',
    OrbitSubscriptionTier.plus => 'Extended history and advanced tools',
  };

  List<String> get benefits => switch (this) {
    OrbitSubscriptionTier.free => const <String>[
      'Circles, messaging, Moments, presence, SOS and Ping',
      '30-day activity history and 7-day Moments history',
      'Sponsored cards in the Activity Feed only',
    ],
    OrbitSubscriptionTier.lite => const <String>[
      'Everything in Free, without Activity Feed ads',
      '90-day activity history',
      '14-day Moments history',
    ],
    OrbitSubscriptionTier.plus => const <String>[
      'Everything in Lite',
      '1-year activity and 30-day Moments history',
      'Enhanced SOS routing and SMS fallback where supported',
      'Advanced visibility rules and premium themes',
    ],
  };
}

/// Called only when a real billing/API implementation has been injected.
/// This callback must not grant entitlements on a button tap alone: verified
/// store/server subscription state should be returned through [currentTier].
typedef OrbitSubscriptionRequest = FutureOr<void> Function(
  OrbitSubscriptionTier tier,
);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    this.currentTier,
    this.onPlanRequested,
    this.onRestoreRequested,
    this.onBack,
    super.key,
  });

  /// Null means that subscription status has not yet been retrieved.
  final OrbitSubscriptionTier? currentTier;
  final OrbitSubscriptionRequest? onPlanRequested;
  final FutureOr<void> Function()? onRestoreRequested;
  final VoidCallback? onBack;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const double _contentWidth = 600;
  static const double _sidePadding = 20;
  OrbitSubscriptionTier _selectedTier = OrbitSubscriptionTier.free;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedTier;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _sidePadding,
                    20,
                    _sidePadding,
                    0,
                  ),
                  child: AppScreenHeader(
                    title: 'Subscription',
                    titleKey: SubscriptionKeys.title,
                    backButtonKey: SubscriptionKeys.back,
                    onBack: widget.onBack,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    key: SubscriptionKeys.scrollView,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      _sidePadding,
                      0,
                      _sidePadding,
                      16,
                    ),
                    children: <Widget>[
                      Text(
                        'Choose your Orbit plan',
                        style: AppTypography.smallHeading,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All plans keep your trusted circles at the center.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PlanStatusCard(currentTier: widget.currentTier),
                      const SizedBox(height: 16),
                      for (final tier
                          in OrbitSubscriptionTier.values) ...<Widget>[
                        _SubscriptionPlanCard(
                          key: SubscriptionKeys.plan(tier.name),
                          tier: tier,
                          isSelected: selected == tier,
                          isCurrent: widget.currentTier == tier,
                          onPressed: _isBusy
                              ? null
                              : () => setState(() => _selectedTier = tier),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Prices shown are from the Orbit product scope (USD). '
                        'Final availability, local prices and billing terms '
                        'will come from the App Store or Google Play.',
                        style: AppTypography.body.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _sidePadding,
                    8,
                    _sidePadding,
                    16,
                  ),
                  child: Column(
                    children: <Widget>[
                      AppPrimaryButton(
                        key: SubscriptionKeys.purchaseButton,
                        label: _isBusy
                            ? 'Please wait…'
                            : selected == OrbitSubscriptionTier.free
                            ? 'Back to Settings'
                            : 'Choose ${selected.label}',
                        enabled: !_isBusy,
                        onPressed: selected == OrbitSubscriptionTier.free
                            ? _goBack
                            : () => unawaited(_requestPlan(selected)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: SubscriptionKeys.restoreButton,
                        onPressed: _isBusy
                            ? null
                            : () => unawaited(_restorePurchases()),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryEnd,
                          minimumSize: const Size(180, 44),
                        ),
                        child: const Text(
                          'Restore purchases',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestPlan(OrbitSubscriptionTier tier) async {
    final callback = widget.onPlanRequested;
    if (callback == null) {
      _showMessage('Purchases will be available after billing is connected.');
      return;
    }
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await callback(tier);
      // Deliberately do not mark a tier active here. Billing/server verification
      // must update currentTier before an active entitlement is displayed.
    } catch (_) {
      _showMessage(
        'Could not complete the purchase request. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restorePurchases() async {
    final callback = widget.onRestoreRequested;
    if (callback == null) {
      _showMessage(
        'Purchase restoration will be available after billing is connected.',
      );
      return;
    }
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await callback();
      // Verified restored entitlements arrive separately via currentTier.
    } catch (_) {
      _showMessage('Could not restore purchases. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard({required this.currentTier});

  final OrbitSubscriptionTier? currentTier;

  @override
  Widget build(BuildContext context) {
    final tier = currentTier;
    return Container(
      key: SubscriptionKeys.currentPlan,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.primaryEnd,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Current plan',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier == null
                      ? 'Not connected to your account yet'
                      : tier.label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.tier,
    required this.isSelected,
    required this.isCurrent,
    required this.onPressed,
    super.key,
  });

  final OrbitSubscriptionTier tier;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primaryEnd
        : const Color(0xFFEDEAF2);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${tier.label} plan, ${tier.price} per month',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1FA576F6),
                      ),
                      child: Icon(
                        tier == OrbitSubscriptionTier.free
                            ? Icons.favorite_border_rounded
                            : tier == OrbitSubscriptionTier.lite
                            ? Icons.auto_awesome_outlined
                            : Icons.workspace_premium_outlined,
                        color: AppColors.primaryEnd,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tier.label,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            tier.details,
                            style: AppTypography.body.copyWith(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          tier.price,
                          style: AppTypography.body.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '/ month',
                          style: AppTypography.body.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isCurrent) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Your current plan',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primaryEnd,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                for (final benefit in tier.benefits) ...<Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: AppColors.primaryEnd,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: AppTypography.body.copyWith(
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
