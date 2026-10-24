import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../domain/models/moment_publish_models.dart';
import '../widgets/moment_publish_sheet.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../orbit_camera_permission_memory.dart';

abstract final class MomentCameraKeys {
  static const closeButton = Key('moment_camera_close_button');
  static const filterButton = Key('moment_camera_filter_button');
  static const toolsColumn = Key('moment_camera_tools_column');
  static const flashButton = Key('moment_camera_flash_button');
  static const flipButton = Key('moment_camera_flip_button');
  static const timerButton = Key('moment_camera_timer_button');
  static const stickersButton = Key('moment_camera_stickers_button');
  static const textButton = Key('moment_camera_text_button');
  static const captureButton = Key('moment_camera_capture_button');
  static const sendButton = Key('moment_camera_send_button');
  static const countdown = Key('moment_camera_countdown');
  static const capturedPreview = Key('moment_camera_captured_preview');
  static const cameraError = Key('moment_camera_error');
}

class MomentCameraScreen extends StatefulWidget {
  const MomentCameraScreen({
    this.onClose,
    this.onFilterPressed,
    this.onTextPressed,
    this.onStickersPressed,
    this.onCaptured,
    this.onSendPressed,
    this.momentAudienceCircles = const <MomentAudienceCircle>[],
    this.momentAudienceFriends = const <MomentAudienceCircle>[],
    this.momentPrivacyAudience = 'Nobody',
    this.publishMoment,
    this.privateSaver,
    this.enableCamera = true,
    this.initialCameraDirection = CameraLensDirection.front,
    this.resolutionPreset = ResolutionPreset.high,
    super.key,
  });

  final VoidCallback? onClose;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onTextPressed;
  final VoidCallback? onStickersPressed;
  final ValueChanged<Uint8List>? onCaptured;
  final ValueChanged<Uint8List>? onSendPressed;

  /// Inject real memberships and a confirmed publisher with the backend.
  /// Without a publisher the photo flow is explicitly UI-preview only.
  final List<MomentAudienceCircle> momentAudienceCircles;
  final List<MomentAudienceCircle> momentAudienceFriends;
  final String momentPrivacyAudience;
  final MomentPublisher? publishMoment;
  final OrbitPrivatePhotoSaver? privateSaver;

  /// Defaults to true in the real app. Tests can turn this off so widget tests
  /// never invoke a platform camera channel.
  final bool enableCamera;
  final CameraLensDirection initialCameraDirection;
  final ResolutionPreset resolutionPreset;

  @override
  State<MomentCameraScreen> createState() => _MomentCameraScreenState();
}

class _MomentCameraScreenState extends State<MomentCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _activeCamera;
  List<CameraDescription> _cameras = const <CameraDescription>[];

  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _cameraError;
  Uint8List? _capturedBytes;
  bool _publishSheetOpen = false;

  FlashMode _flashMode = FlashMode.off;
  Duration _captureDelay = Duration.zero;
  int? _countdownValue;
  bool _orbitLoadingPopupVisible = false;
  bool _orbitErrorPopupVisible = false;
  bool _cameraInitializationInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.enableCamera) {
      unawaited(_initializeCamera());
    } else {
      _isInitializing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableCamera) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Android's runtime permission UI temporarily moves the activity to an
      // inactive state while CameraController.initialize() is still waiting
      // for the permission result. Disposing/restarting here creates two
      // competing camera initializations and causes the false error popup.
      if (_cameraInitializationInProgress) {
        return;
      }

      final controller = _controller;
      _controller = null;
      unawaited(controller?.dispose());
      return;
    }

    if (state == AppLifecycleState.resumed && _capturedBytes == null) {
      // If the permission dialog resumed the app while the original
      // initialization is still running, let that one finish. Never start a
      // second CameraController concurrently.
      if (_cameraInitializationInProgress) {
        return;
      }

      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        unawaited(_initializeCamera(preferredCamera: _activeCamera));
      }
    }
  }

  Future<void> _showOrbitCameraLoadingPopup() async {
    if (_orbitLoadingPopupVisible || !mounted || !_isInitializing) return;
    final frameReady = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!frameReady.isCompleted) frameReady.complete();
    });
    await frameReady.future;
    if (!mounted || !_isInitializing || _orbitLoadingPopupVisible) return;
    _orbitLoadingPopupVisible = true;
    await showLoadingPopup(context, showCloseButton: false);
    _orbitLoadingPopupVisible = false;
  }

  Future<void> _dismissOrbitCameraLoadingPopup() async {
    if (!_orbitLoadingPopupVisible || !mounted) {
      return;
    }

    _orbitLoadingPopupVisible = false;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _showOrbitMomentErrorPopup() {
    if (_orbitErrorPopupVisible ||
        !mounted ||
        _controller?.value.isInitialized == true) {
      return;
    }
    _orbitErrorPopupVisible = true;
    unawaited(
      showMomentErrorPopup(
        context,
        onRetry: () {
          if (mounted) unawaited(_initializeCamera());
        },
      ).whenComplete(() => _orbitErrorPopupVisible = false),
    );
  }

  Future<void> _initializeCamera({CameraDescription? preferredCamera}) async {
    if (!widget.enableCamera || !mounted || _cameraInitializationInProgress) {
      return;
    }

    _cameraInitializationInProgress = true;

    try {
      if (mounted) {
        setState(() {
          _isInitializing = true;
          _cameraError = null;
        });
      }

      unawaited(_showOrbitCameraLoadingPopup());

      final oldController = _controller;
      _controller = null;
      if (oldController != null) {
        await oldController.dispose();
      }

      final cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera is available on this device.',
        );
      }

      _cameras = cameras;
      final camera = preferredCamera ?? _pickInitialCamera(cameras);
      final controller = CameraController(
        camera,
        widget.resolutionPreset,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _activeCamera = camera;
      _controller = controller;
      _flashMode = FlashMode.off;

      unawaited(OrbitCameraPermissionMemory.markCameraAccessConfirmed());

      await _trySetFlashMode(FlashMode.off, updateState: false);

      if (!mounted) {
        return;
      }

      await _dismissOrbitCameraLoadingPopup();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _cameraError = null;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      await _dismissOrbitCameraLoadingPopup();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _cameraError = _friendlyCameraError(error);
      });

      _showOrbitMomentErrorPopup();
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _dismissOrbitCameraLoadingPopup();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _cameraError = 'Camera could not be started. Please try again.';
      });

      _showOrbitMomentErrorPopup();
    } finally {
      _cameraInitializationInProgress = false;
    }
  }

  CameraDescription _pickInitialCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == widget.initialCameraDirection) {
        return camera;
      }
    }
    return cameras.first;
  }

  String _friendlyCameraError(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera access is required to create a Moment.';
      default:
        return error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Camera could not be started. Please try again.';
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturedBytes != null) {
      return;
    }

    const modes = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.always];
    final currentIndex = modes.indexOf(_flashMode);

    for (var offset = 1; offset <= modes.length; offset++) {
      final candidate = modes[(currentIndex + offset) % modes.length];
      if (await _trySetFlashMode(candidate)) {
        return;
      }
    }
  }

  Future<bool> _trySetFlashMode(
    FlashMode mode, {
    bool updateState = true,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }

    try {
      await controller.setFlashMode(mode);
      if (updateState && mounted) {
        setState(() => _flashMode = mode);
      } else {
        _flashMode = mode;
      }
      return true;
    } on CameraException {
      return false;
    }
  }

  Future<void> _flipCamera() async {
    if (_capturedBytes != null || _cameras.length < 2 || _isInitializing) {
      return;
    }

    final active = _activeCamera;
    if (active == null) {
      return;
    }

    CameraDescription? nextCamera;
    final currentIndex = _cameras.indexWhere(
      (camera) => camera.name == active.name,
    );
    for (var offset = 1; offset <= _cameras.length; offset++) {
      final candidate = _cameras[(currentIndex + offset) % _cameras.length];
      if (candidate.lensDirection != active.lensDirection) {
        nextCamera = candidate;
        break;
      }
    }

    if (nextCamera != null) {
      await _initializeCamera(preferredCamera: nextCamera);
    }
  }

  void _cycleTimer() {
    if (_capturedBytes != null || _isCapturing) {
      return;
    }

    setState(() {
      if (_captureDelay == Duration.zero) {
        _captureDelay = const Duration(seconds: 3);
      } else if (_captureDelay == const Duration(seconds: 3)) {
        _captureDelay = const Duration(seconds: 10);
      } else {
        _captureDelay = Duration.zero;
      }
    });
  }

  Future<void> _handleCapturePressed() async {
    if (_capturedBytes != null) {
      await _retake();
      return;
    }
    await _captureMoment();
  }

  Future<void> _captureMoment() async {
    final controller = _controller;
    if (_isCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final delaySeconds = _captureDelay.inSeconds;
      for (var second = delaySeconds; second > 0; second--) {
        if (!mounted) {
          return;
        }
        setState(() => _countdownValue = second);
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (!mounted) {
        return;
      }
      setState(() => _countdownValue = null);

      final file = await controller.takePicture();
      late final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } finally {
        // The camera plugin stages an unencrypted temporary original.
        // Never retain that file after moving the photo into memory.
        final plaintext = File(file.path);
        if (await plaintext.exists()) {
          try { await plaintext.delete(); } on FileSystemException {
            // OS cleanup remains a separate fallback; no plaintext is uploaded.
          }
        }
      }

      try {
        await controller.pausePreview();
      } on CameraException {
        // Some camera implementations do not support pausing the preview.
      }

      if (!mounted) {
        return;
      }
      setState(() => _capturedBytes = bytes);
      widget.onCaptured?.call(bytes);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _cameraError = _friendlyCameraError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _countdownValue = null;
        });
      }
    }
  }

  Future<void> _retake() async {
    if (!mounted) {
      return;
    }

    setState(() => _capturedBytes = null);
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.resumePreview();
      } on CameraException {
        await _initializeCamera(preferredCamera: _activeCamera);
      }
    } else {
      await _initializeCamera(preferredCamera: _activeCamera);
    }
  }

  Future<void> _handleSendPressed() async {
    final captured = _capturedBytes;
    if (captured == null) {
      await _captureMoment();
      return;
    }
    // Preserve existing explicit Send integrations, including legacy tests.
    final legacySend = widget.onSendPressed;
    if (legacySend != null) {
      legacySend(captured);
      return;
    }
    if (_publishSheetOpen || !mounted) return;
    // Step7:photo-publishing-flow â€” the camera and its permission lifecycle
    // stay mounted under this sheet; no additional camera instance is created.
    _publishSheetOpen = true;
    try {
      await showMomentPublishingSheet(
        context,
        photoBytes: captured,
        // An authenticated account must never show fabricated Circle names.
        circles: widget.momentAudienceCircles,
        friends: widget.momentAudienceFriends,
        privacyAudience: widget.momentPrivacyAudience,
        publisher: widget.publishMoment,
        privateSaver: widget.privateSaver,
      );
    } finally {
      _publishSheetOpen = false;
    }
  }

  void _close() {
    final callback = widget.onClose;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildCameraBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final edgePadding = constraints.maxWidth <= 340 ? 12.0 : 20.0;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Positioned(
                        top: 8,
                        left: edgePadding,
                        child: _CameraTopButton(
                          key: MomentCameraKeys.closeButton,
                          semanticLabel: 'Close camera',
                          assetPath: 'assets/icons/close.svg',
                          onTap: _close,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: edgePadding,
                        child: _CameraTopButton(
                          key: MomentCameraKeys.filterButton,
                          semanticLabel: 'Camera filters and settings',
                          assetPath: 'assets/icons/filter.svg',
                          onTap: widget.onFilterPressed ?? () {},
                        ),
                      ),
                      Positioned(
                        top: 70,
                        right: edgePadding,
                        child: _buildToolColumn(),
                      ),
                      Positioned(
                        left: edgePadding,
                        right: edgePadding,
                        bottom: 10,
                        height: 78,
                        child: _buildBottomControls(
                          compact: constraints.maxWidth <= 440,
                        ),
                      ),
                      if (_countdownValue != null)
                        Center(
                          child: Text(
                            '${_countdownValue!}',
                            key: MomentCameraKeys.countdown,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontFamilyFallback: const <String>[
                                'Noto Color Emoji',
                                'Apple Color Emoji',
                                'Segoe UI Emoji',
                              ],
                              fontSize: 56,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0x80000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBackground() {
    final captured = _capturedBytes;
    if (captured != null) {
      return Image.memory(
        captured,
        key: MomentCameraKeys.capturedPreview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (!widget.enableCamera) {
      return const ColoredBox(color: Color(0xFF95C7D2));
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return _CoverCameraPreview(controller: controller);
    }

    if (_cameraError != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42),
            child: Column(
              key: MomentCameraKeys.cameraError,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 36,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: const <String>[
                      'Noto Color Emoji',
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                    ],
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => _initializeCamera(),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: const <String>[
                        'Noto Color Emoji',
                        'Apple Color Emoji',
                        'Segoe UI Emoji',
                      ],
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return const ColoredBox(color: Colors.black);
  }

  Widget _buildToolColumn() {
    final timerSeconds = _captureDelay.inSeconds;
    final flashSemantic = switch (_flashMode) {
      FlashMode.off => 'Flash off',
      FlashMode.auto => 'Flash auto',
      FlashMode.always => 'Flash always on',
      FlashMode.torch => 'Flash torch on',
    };
    final timerSemantic = timerSeconds == 0
        ? 'Timer off'
        : 'Timer $timerSeconds seconds';

    return Column(
      key: MomentCameraKeys.toolsColumn,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CameraToolItem(
          key: MomentCameraKeys.flashButton,
          semanticLabel: flashSemantic,
          assetPath: 'assets/icons/flash.svg',
          label: 'Flash',
          onTap: _toggleFlash,
        ),
        const SizedBox(height: 10),
        _CameraToolItem(
          key: MomentCameraKeys.flipButton,
          semanticLabel: 'Flip camera',
          assetPath: 'assets/icons/flip.svg',
          label: 'Flip',
          onTap: _flipCamera,
        ),
        const SizedBox(height: 10),
        _CameraToolItem(
          key: MomentCameraKeys.timerButton,
          semanticLabel: timerSemantic,
          assetPath: 'assets/icons/timer.svg',
          label: 'Timer',
          onTap: _cycleTimer,
        ),
        const SizedBox(height: 10),
        _CameraToolItem(
          key: MomentCameraKeys.stickersButton,
          semanticLabel: 'Open stickers',
          assetPath: 'assets/icons/sticker.svg',
          label: 'Stickers',
          onTap: widget.onStickersPressed ?? () {},
        ),
      ],
    );
  }

  Widget _buildBottomControls({required bool compact}) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: _CameraTextButton(
            key: MomentCameraKeys.textButton,
            onTap: widget.onTextPressed ?? () {},
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: _CaptureButton(
            key: MomentCameraKeys.captureButton,
            isBusy: _isCapturing,
            onTap: _handleCapturePressed,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _SendToButton(
            key: MomentCameraKeys.sendButton,
            compact: compact,
            onTap: _handleSendPressed,
          ),
        ),
      ],
    );
  }
}

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final childWidth = isPortrait ? previewSize.height : previewSize.width;
    final childHeight = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: childWidth,
            height: childHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraTopButton extends StatelessWidget {
  const _CameraTopButton({
    required this.semanticLabel,
    required this.assetPath,
    required this.onTap,
    super.key,
  });

  final String semanticLabel;
  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: false,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: SizedBox.square(
              dimension: 36,
              child: Center(
                child: SvgPicture.asset(
                  assetPath,
                  width: 26,
                  height: 26,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraToolItem extends StatelessWidget {
  const _CameraToolItem({
    required this.semanticLabel,
    required this.assetPath,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String semanticLabel;
  final String assetPath;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x21000000),
                border: Border.all(width: 1, color: const Color(0x2EFFFFFF)),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assetPath,
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const <String>[
                  'Noto Color Emoji',
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                ],
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTextButton extends StatelessWidget {
  const _CameraTextButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add text',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/text.svg',
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.isBusy, required this.onTap, super.key});

  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isBusy ? 'Capturing moment' : 'Capture moment',
      child: InkResponse(
        onTap: isBusy ? null : onTap,
        customBorder: const CircleBorder(),
        radius: 42,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendToButton extends StatelessWidget {
  const _SendToButton({required this.compact, required this.onTap, super.key});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send To',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          gradient: AppBottomNavigationBar.addButtonGradient,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 108, minHeight: 46),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 1 : 18,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Send To',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontFamilyFallback: const <String>[
                          'Noto Color Emoji',
                          'Apple Color Emoji',
                          'Segoe UI Emoji',
                        ],
                        fontSize: compact ? 12 : 15,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: compact ? 3 : 5),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: compact ? 16 : 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
