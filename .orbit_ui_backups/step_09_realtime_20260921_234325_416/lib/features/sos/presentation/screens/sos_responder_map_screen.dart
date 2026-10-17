import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_typography.dart';

/// A responder, as supplied by the authenticated SOS service. Never fabricated.
@immutable
class SosResponderPerson {
  const SosResponderPerson({
    required this.id,
    required this.name,
    required this.status,
    this.avatarPath,
    this.etaLabel,
  });

  final String id;
  final String name;
  final String status;
  final String? avatarPath;
  final String? etaLabel;
}

/// Server-confirmed SOS data. UI does not activate, acknowledge or resolve SOS.
@immutable
class SosResponderSession {
  const SosResponderSession({
    required this.id,
    required this.serverConfirmed,
    required this.originatorName,
    required this.circleName,
    required this.status,
    required this.responders,
    this.isOriginator = true,
    this.deliveryLabel = 'Waiting for an update',
    this.recordingLabel = 'Recording status unavailable',
    this.locationLabel = 'Location unavailable',
  });

  final String id;
  final bool serverConfirmed;
  final String originatorName;
  final String circleName;
  final String status;
  final List<SosResponderPerson> responders;
  final bool isOriginator;
  final String deliveryLabel;
  final String recordingLabel;
  final String locationLabel;
}

abstract final class SosResponderMapKeys {
  static const screen = Key('sos_responder_map_screen');
  static const previewBanner = Key('sos_responder_preview_banner');
  static const liveBanner = Key('sos_responder_live_banner');
  static const map = Key('sos_responder_map');
  static const emptyResponders = Key('sos_responder_empty_responders');
  static const resolveButton = Key('sos_responder_resolve_button');
  static const engageButton = Key('sos_responder_engage_button');
}

/// Orbit UI-only responder view. `session` must come from the SOS backend.
/// Without an acknowledged session, the surface is explicitly marked preview.
/// Live location is rendered ONLY when the caller supplies [liveMap].
class SosResponderMapScreen extends StatefulWidget {
  const SosResponderMapScreen({
    this.session,
    this.liveMap,
    this.onResolve,
    this.onEngage,
    super.key,
  });

  final SosResponderSession? session;
  final Widget? liveMap;
  final Future<bool> Function(String sosId)? onResolve;
  final Future<bool> Function(String sosId)? onEngage;

  @override
  State<SosResponderMapScreen> createState() => _SosResponderMapScreenState();
}

class _SosResponderMapScreenState extends State<SosResponderMapScreen> {
  static const Color _background = Color(0xFF0D0F20);
  static const Color _panel = Color(0xFF191D2E);
  static const Color _muted = Color(0xFFADB4C2);
  static const Color _danger = Color(0xFFE84040);
  static const Color _divider = Color(0xFF303448);

  bool _busy = false;
  String? _actionError;

  bool get _hasConfirmedSession =>
      widget.session != null &&
      widget.session!.serverConfirmed &&
      widget.session!.id.trim().isNotEmpty;

  bool get _isOriginator => widget.session?.isOriginator ?? true;

  Future<void> _performAction({required bool resolve}) async {
    if (_busy || !_hasConfirmedSession) return;
    final handler = resolve ? widget.onResolve : widget.onEngage;
    if (handler == null) return;
    if (resolve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resolve this SOS?'),
          content: const Text(
            'Only confirm after your emergency is over. '
            'The server must acknowledge resolution.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Resolve SOS'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final acknowledged = await handler(widget.session!.id);
      if (!mounted) return;
      if (acknowledged) {
        if (resolve) {
          Navigator.of(context).maybePop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Response confirmed by the SOS service.'),
            ),
          );
        }
      } else {
        setState(
          () => _actionError =
              'The SOS service did not confirm this action. Please retry.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Unable to reach the SOS service. No confirmation was received.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _hasConfirmedSession ? widget.session : null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: SosResponderMapKeys.screen,
        backgroundColor: _background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: <Widget>[
              _header(),
              const SizedBox(height: 20),
              _statusBanner(session),
              const SizedBox(height: 16),
              _sectionTitle('Responder map'),
              const SizedBox(height: 10),
              _mapPanel(session),
              const SizedBox(height: 16),
              _detailsPanel(session),
              const SizedBox(height: 20),
              _sectionTitle('Responders'),
              const SizedBox(height: 10),
              _responders(session),
              if (_actionError != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  _actionError!,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    color: Color(0xFFFF9999),
                  ),
                ),
              ],
              if (session != null) ...<Widget>[
                const SizedBox(height: 18),
                if (_isOriginator && widget.onResolve != null)
                  _actionButton(
                    label: _busy ? 'Please wait...' : 'Resolve SOS',
                    key: SosResponderMapKeys.resolveButton,
                    onPressed: _busy
                        ? null
                        : () => _performAction(resolve: true),
                  ),
                if (!_isOriginator && widget.onEngage != null)
                  _actionButton(
                    label: _busy ? 'Please wait...' : "I'm coming",
                    key: SosResponderMapKeys.engageButton,
                    onPressed: _busy
                        ? null
                        : () => _performAction(resolve: false),
                  ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Orbit is not an emergency service. If you need immediate help, '
                'contact your local emergency services directly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  height: 1.5,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => SizedBox(
    height: 50,
    child: Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 21,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Expanded(
          child: Text(
            'SOS Responder Map',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _statusBanner(SosResponderSession? session) {
    final isPreview = session == null;
    return Container(
      key: isPreview
          ? SosResponderMapKeys.previewBanner
          : SosResponderMapKeys.liveBanner,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPreview ? const Color(0xFF342220) : const Color(0xFF302024),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _danger.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isPreview ? Icons.visibility_outlined : Icons.sos_rounded,
            color: const Color(0xFFFF9B99),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isPreview
                      ? 'Preview only — no SOS was sent'
                      : 'SOS service confirmed',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isPreview
                      ? 'This is a UI preview. Alerts, recording, location sharing and responder notifications are not active.'
                      : '${session!.circleName}  •  ${session.status}',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFFE2C9C9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPanel(SosResponderSession? session) => Container(
    key: SosResponderMapKeys.map,
    height: 220,
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _divider),
    ),
    clipBehavior: Clip.antiAlias,
    child: session != null && widget.liveMap != null
        ? widget.liveMap!
        : Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Reuse Orbit's visual map surface, but NEVER present this
              // static asset as a real live location or actual SOS pin.
              Image.asset(
                'assets/orbit_map.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: _panel),
              ),
              const ColoredBox(color: Color(0xCC0D0F20)),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.location_off_outlined,
                        color: Colors.white70,
                        size: 29,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Live map not connected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Locations and map pins are displayed only when provided by the authorized SOS service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFFCAD0DB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );

  Widget _detailsPanel(SosResponderSession? session) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _detailRow(
          Icons.person_outline_rounded,
          'Originator',
          session?.originatorName ?? 'Not connected',
        ),
        const Divider(height: 22, color: _divider),
        _detailRow(
          Icons.location_on_outlined,
          'Location',
          session?.locationLabel ?? 'No location shared',
        ),
        const Divider(height: 22, color: _divider),
        _detailRow(
          Icons.notifications_active_outlined,
          'Alert delivery',
          session?.deliveryLabel ?? 'No alert sent',
        ),
        const Divider(height: 22, color: _divider),
        _detailRow(
          Icons.mic_none_outlined,
          'Audio recording',
          session?.recordingLabel ?? 'Not recording',
        ),
      ],
    ),
  );

  Widget _detailRow(IconData icon, String label, String value) => Row(
    children: <Widget>[
      Icon(icon, color: _muted, size: 20),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                color: _muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _sectionTitle(String value) => Text(
    value,
    style: const TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  );

  Widget _responders(SosResponderSession? session) {
    if (session == null || session.responders.isEmpty) {
      return Container(
        key: SosResponderMapKeys.emptyResponders,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No confirmed responder information available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            height: 1.4,
            color: _muted,
          ),
        ),
      );
    }
    return Column(
      children: session.responders
          .map(
            (person) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF303448),
                      child: Text(
                        person.name.isEmpty ? '?' : person.name.substring(0, 1),
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            person.name,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            person.status,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (person.etaLabel != null)
                      Text(
                        person.etaLabel!,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: Color(0xFFED65C9),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _actionButton({
    required String label,
    required Key key,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      key: key,
      style: ElevatedButton.styleFrom(
        backgroundColor: _danger,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
