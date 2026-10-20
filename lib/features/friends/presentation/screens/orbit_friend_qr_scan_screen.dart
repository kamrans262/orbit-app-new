import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../data/orbit_social_repository.dart';

/// Reads QR payload but does not redeem automatically. The authenticated
/// preview and explicit confirmation happen in the calling screen.
class OrbitFriendQrScanScreen extends StatefulWidget {
  const OrbitFriendQrScanScreen({super.key, this.repository});
  final OrbitSocialRepository? repository;
  @override
  State<OrbitFriendQrScanScreen> createState() => _OrbitFriendQrScanScreenState();
}

class _OrbitFriendQrScanScreenState extends State<OrbitFriendQrScanScreen> {
  late final OrbitSocialRepository _repository = widget.repository ?? OrbitSocialRepository();
  final MobileScannerController _camera = MobileScannerController(
    formats: <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _consumed = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_consumed || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      try {
        final code = _repository.invitationCode(value);
        _consumed = true;
        Navigator.of(context).pop(code);
        return;
      } on FormatException {
        setState(() => _error = 'This QR code is not an Orbit friend invitation.');
      }
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(child: Column(children: [
      const Padding(padding: EdgeInsets.all(20),
        child: AppScreenHeader(title: 'Scan Friend Invitation')),
      Expanded(child: Padding(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Camera access is unavailable. Enter the friend invitation code manually instead.',
                  textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      )),
      if (_error != null) Padding(padding: const EdgeInsets.all(12),
        child: Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB91C1C)))),
      const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Text('Only Orbit invitation QR codes are accepted. Scanning does not automatically send a friend request.',
          textAlign: TextAlign.center)),
    ])),
  );
}
