import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_circular_icon_button.dart';
import '../../domain/models/request_models.dart';
import '../widgets/request_card.dart';

abstract final class RequestScreenKeys {
  static const backButton = Key('request_back_button');
  static const title = Key('request_title');
  static const scrollView = Key('request_scroll_view');
  static const peopleHeading = Key('request_people_heading');
  static const circlesHeading = Key('request_circles_heading');
  static const retryButton = Key('request_retry_button');

  static Key entry(String id) => Key('request_entry_$id');
}

typedef RequestActionCallback = FutureOr<void> Function(RequestData request);

class RequestScreen extends StatefulWidget {
  const RequestScreen({
    required this.peopleRequests,
    required this.circleRequests,
    required this.onBack,
    required this.onAccept,
    required this.onIgnore,
    this.viewState = RequestViewState.loaded,
    this.errorMessage = 'Something went wrong. Please try again.',
    this.onRetry,
    super.key,
  });

  factory RequestScreen.demo({VoidCallback? onBack}) {
    return RequestScreen(
      peopleRequests: const <RequestData>[
        RequestData(
          id: 'person-mike',
          name: 'Mike',
          supportingText: 'Wants to Add as a friend.',
          imagePath: 'assets/Mike.png',
        ),
        RequestData(
          id: 'person-sophia',
          name: 'Sophia',
          supportingText: 'Wants to Add as a friend.',
          imagePath: 'assets/Sophia.png',
        ),
      ],
      circleRequests: const <RequestData>[
        RequestData(
          id: 'circle-weekend',
          name: 'Weekend crew',
          supportingText: 'Invited you to join this circle.',
          imagePath: 'assets/Emma.png',
        ),
      ],
      onBack: onBack ?? () {},
      onAccept: (_) {},
      onIgnore: (_) {},
    );
  }

  final List<RequestData> peopleRequests;
  final List<RequestData> circleRequests;
  final VoidCallback onBack;
  final RequestActionCallback onAccept;
  final RequestActionCallback onIgnore;
  final RequestViewState viewState;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerGap = 20;
  static const double _headingToListGap = 16;
  static const double _cardGap = 10;
  static const double _sectionGap = 20;

  late List<RequestData> _peopleRequests;
  late List<RequestData> _circleRequests;

  @override
  void initState() {
    super.initState();
    _peopleRequests = List<RequestData>.of(widget.peopleRequests);
    _circleRequests = List<RequestData>.of(widget.circleRequests);
  }

  @override
  void didUpdateWidget(covariant RequestScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.peopleRequests, widget.peopleRequests)) {
      _peopleRequests = List<RequestData>.of(widget.peopleRequests);
    }
    if (!identical(oldWidget.circleRequests, widget.circleRequests)) {
      _circleRequests = List<RequestData>.of(widget.circleRequests);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          key: RequestScreenKeys.scrollView,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: _topPadding)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(child: _buildHeader()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _headerGap)),
            ..._buildContent(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          AppCircularIconButton(
            key: RequestScreenKeys.backButton,
            semanticLabel: 'Back',
            onPressed: widget.onBack,
            icon: Icons.chevron_left_rounded,
            iconSize: 24,
            iconColor: Colors.black,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Request',
              key: RequestScreenKeys.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    switch (widget.viewState) {
      case RequestViewState.loading:
        return const <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _RequestLoadingState(),
          ),
        ];
      case RequestViewState.error:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _RequestErrorState(
              message: widget.errorMessage,
              onRetry: widget.onRetry,
            ),
          ),
        ];
      case RequestViewState.loaded:
        return <Widget>[
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: _RequestSectionHeading(
                key: RequestScreenKeys.peopleHeading,
                label: 'People',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _headingToListGap)),
          ..._buildRequestSection(
            requests: _peopleRequests,
            emptyLabel: 'No people requests right now.',
            isPeopleSection: true,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _sectionGap)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            sliver: SliverToBoxAdapter(
              child: _RequestSectionHeading(
                key: RequestScreenKeys.circlesHeading,
                label: 'Circles',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: _headingToListGap)),
          ..._buildRequestSection(
            requests: _circleRequests,
            emptyLabel: 'No circle requests right now.',
            isPeopleSection: false,
          ),
        ];
    }
  }

  List<Widget> _buildRequestSection({
    required List<RequestData> requests,
    required String emptyLabel,
    required bool isPeopleSection,
  }) {
    if (requests.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          sliver: SliverToBoxAdapter(child: _RequestEmptyState(emptyLabel)),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final request = requests[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == requests.length - 1 ? 0 : _cardGap,
              ),
              child: _AnimatedRequestEntry(
                key: ValueKey<String>(
                  '${isPeopleSection ? 'people' : 'circle'}-${request.id}',
                ),
                request: request,
                onAccept: () => _runAction(request: request, accept: true),
                onIgnore: () => _runAction(request: request, accept: false),
                onRemoved: () => _removeRequest(request, isPeopleSection),
              ),
            );
          }, childCount: requests.length),
        ),
      ),
    ];
  }

  Future<bool> _runAction({
    required RequestData request,
    required bool accept,
  }) async {
    try {
      if (accept) {
        await Future<void>.sync(() => widget.onAccept(request));
      } else {
        await Future<void>.sync(() => widget.onIgnore(request));
      }
      if (!mounted) {
        return false;
      }
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Could not accept this request. Please try again.'
                : 'Could not ignore this request. Please try again.',
          ),
        ),
      );
      return false;
    }
  }

  void _removeRequest(RequestData request, bool isPeopleSection) {
    if (!mounted) {
      return;
    }

    setState(() {
      final target = isPeopleSection ? _peopleRequests : _circleRequests;
      target.removeWhere((item) => item.id == request.id);
    });
  }
}

class _AnimatedRequestEntry extends StatefulWidget {
  const _AnimatedRequestEntry({
    required this.request,
    required this.onAccept,
    required this.onIgnore,
    required this.onRemoved,
    super.key,
  });

  final RequestData request;
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onIgnore;
  final VoidCallback onRemoved;

  @override
  State<_AnimatedRequestEntry> createState() => _AnimatedRequestEntryState();
}

class _AnimatedRequestEntryState extends State<_AnimatedRequestEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _size;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _size = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleAction({required bool accept}) async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    final succeeded = accept
        ? await widget.onAccept()
        : await widget.onIgnore();

    if (!mounted) {
      return;
    }
    if (!succeeded) {
      setState(() => _busy = false);
      return;
    }

    await _controller.reverse();
    if (!mounted) {
      return;
    }

    widget.onRemoved();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      key: RequestScreenKeys.entry(widget.request.id),
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        child: RequestCard(
          data: widget.request,
          isBusy: _busy,
          onAccept: () => _handleAction(accept: true),
          onIgnore: () => _handleAction(accept: false),
        ),
      ),
    );
  }
}

class _RequestSectionHeading extends StatelessWidget {
  const _RequestSectionHeading({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: const <String>[
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F1724),
      ),
    );
  }
}

class _RequestEmptyState extends StatelessWidget {
  const _RequestEmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: const <String>[
            'Noto Color Emoji',
            'Apple Color Emoji',
            'Segoe UI Emoji',
          ],
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _RequestLoadingState extends StatelessWidget {
  const _RequestLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
    );
  }
}

class _RequestErrorState extends StatelessWidget {
  const _RequestErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            message.trim().isEmpty
                ? 'Something went wrong. Please try again.'
                : message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: const <String>[
                'Noto Color Emoji',
                'Apple Color Emoji',
                'Segoe UI Emoji',
              ],
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 16),
            TextButton(
              key: RequestScreenKeys.retryButton,
              onPressed: onRetry,
              child: const Text(
                'Try again',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: const <String>[
                    'Noto Color Emoji',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                  ],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
