import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:compress_video/compress_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/moment_publish_models.dart';
import '../../data/orbit_moment_capture_vault.dart';
import '../../data/moment_photo_processor.dart';
import '../widgets/moment_publish_sheet.dart';
import '../../../../core/widgets/app_bottom_navigation_bar.dart';
import '../../../../core/popups/orbit_popup_variants.dart';
import '../../../../core/popups/orbit_popup_modal.dart';
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
  static const galleryButton = Key('moment_camera_gallery_button');
  static const videoMode = Key('moment_camera_video_mode');
  static const voiceMode = Key('moment_camera_voice_mode');
  static const sendButton = Key('moment_camera_send_button');
  static const countdown = Key('moment_camera_countdown');
  static const capturedPreview = Key('moment_camera_captured_preview');
  static const cameraError = Key('moment_camera_error');
  static const filterTray = Key('moment_camera_filter_tray');
  static const toolHint = Key('moment_camera_tool_hint');
  static const savedDraftBanner = Key('moment_camera_saved_draft_banner');
  static const resumeDraft = Key('moment_camera_resume_draft');
  static const discardDraft = Key('moment_camera_discard_draft');
  static const retakeButton = Key('moment_camera_retake_button');
  static const stickerTray = Key('moment_camera_sticker_tray');
  static const drawButton = Key('moment_camera_draw_button');
  static const drawPalette = Key('moment_camera_draw_palette');
  static const photoInk = Key('moment_camera_photo_ink');
  static const voiceConsent = Key('moment_camera_voice_consent');
  static Key sticker(String id) => Key('moment_camera_sticker_$id');
  static Key filter(String name) => Key('moment_camera_filter_${name}');
}

enum _OrbitCaptureMode { photo, video, voice }

class _CameraSticker {
  _CameraSticker(this.id, this.emoji, this.position);
  final int id;
  final String emoji;
  Offset position;
}

class _CameraInkStroke {
  _CameraInkStroke(this.color, this.points);
  final Color color;
  final List<Offset> points;
}

class MomentCameraScreen extends StatefulWidget {
  const MomentCameraScreen({
    this.onClose,
    this.onFilterPressed,
    this.onTextPressed,
    this.onStickersPressed,
    this.onCaptured,
    this.onSendPressed,
    this.galleryPicker,
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
  /// Testable native photo-picker adapter; actual device picker is the default.
  final Future<Uint8List?> Function()? galleryPicker;

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
  Future<void>? _cameraDisposalInFlight;
  CameraDescription? _activeCamera;
  List<CameraDescription> _cameras = const <CameraDescription>[];

  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isRetaking = false;
  String? _cameraError;
  Uint8List? _capturedBytes;
  bool _publishSheetOpen = false;
  _OrbitCaptureMode _mode=_OrbitCaptureMode.photo;
  final AudioRecorder _audioRecorder=AudioRecorder();
  final OrbitMomentCaptureVault _captureVault=OrbitMomentCaptureVault();
  bool _hasSavedDraft=false;
  bool _restoringSavedDraft=false;
  String? _captureClientId;
  File? _capturedClip;
  int? _capturedDurationMs;
  DateTime? _recordStart;
  Timer? _recordLimit;
  Timer? _recordTicker;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final List<double> _waveform=[];
  int _elapsedSeconds=0;
  bool _stopWhenStarted=false;
  bool _recording=false;
  double _zoomStart=1,_currentZoom=1,_minZoom=1,_maxZoom=1;

  FlashMode _flashMode = FlashMode.off;
  Duration _captureDelay = Duration.zero;
  MomentFilter _selectedFilter = MomentFilter.natural;
  bool _filterTrayOpen = false;
  final GlobalKey _photoCompositionKey=GlobalKey();
  final List<_CameraSticker> _photoStickers=[];
  final List<_CameraInkStroke> _photoStrokes=[];
  _CameraInkStroke? _activePhotoStroke;
  bool _stickerTrayOpen=false;
  bool _drawMode=false;
  bool _exportingPhoto=false;
  int _stickerCounter=0;
  Color _inkColor=Colors.white;
  static const List<String> _stickerChoices=<String>[
    '❤️','😂','😍','🔥','🎉','⭐','🌸','💖','👍','👑','🌈','✨',
  ];
  static const List<Color> _inkColors=<Color>[
    Colors.white,Color(0xFF111827),Color(0xFFF44336),Color(0xFFFFC107),
    Color(0xFF4CAF50),Color(0xFF2196F3),Color(0xFF9C27B0),
  ];
  String? _toolHint;
  Timer? _toolHintTimer;
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
      unawaited(_checkSavedDraft());
    } else {
      _isInitializing = false;
    }
  }

  Future<void> _checkSavedDraft() async {
    try {
      final available=await _captureVault.hasRecoverableDraft();
      if(mounted)setState(()=>_hasSavedDraft=available);
    } catch (_) {
      // Signed-out or revoked accounts must not surface old captures.
      if(mounted)setState(()=>_hasSavedDraft=false);
    }
  }

  Future<void> _discardSavedDraft() async {
    if(_restoringSavedDraft)return;
    try {
      await _captureVault.clear();
      if(mounted)setState(()=>_hasSavedDraft=false);
    } catch (_) {
      _showToolHint('Could not discard saved draft. Try again.');
    }
  }

  Future<void> _restoreEncryptedCapture() async {
    if(_restoringSavedDraft || _isCapturing || _recording ||
       _capturedBytes!=null || _capturedClip!=null)return;
    setState(()=>_restoringSavedDraft=true);
    try {
      final recovered=await _captureVault.restore();
      if(recovered==null){
        if(mounted)setState(()=>_hasSavedDraft=false);
        return;
      }
      if(!mounted || _isCapturing || _recording ||
          _capturedBytes!=null || _capturedClip!=null){
        final clip=recovered.clip;
        if(clip!=null)await _deleteClip(clip);
        return;
      }
      try{await _controller?.pausePreview();}catch(_){}
      if(!mounted){
        final clip=recovered.clip;
        if(clip!=null)await _deleteClip(clip);
        return;
      }
      setState((){
        _mode=recovered.kind=='video' ? _OrbitCaptureMode.video :
          recovered.kind=='audio' ? _OrbitCaptureMode.voice :
          _OrbitCaptureMode.photo;
        _capturedBytes=recovered.photo;
        _capturedClip=recovered.clip;
        _capturedDurationMs=recovered.durationMs;
        _captureClientId=recovered.clientId;
        _hasSavedDraft=false;
        _filterTrayOpen=false;
      });
    }catch(_){
      // Corrupt/cross-account drafts never become a public-media fallback.
      _showToolHint('Saved Moment could not be resumed.');
    }finally{
      if(mounted)setState(()=>_restoringSavedDraft=false);
    }
  }

  Future<void> _savePhotoDraft(Uint8List bytes) async {
    if(!widget.enableCamera)return;
    try{
      _captureClientId=await _captureVault.savePhoto(bytes);
      if(mounted)setState(()=>_hasSavedDraft=false);
    }
    catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'Capture preview is available, but encrypted draft recovery failed.')));
    }
  }

  Future<void> _saveClipDraft(File clip,String kind,int duration) async {
    if(!widget.enableCamera)return;
    try{
      _captureClientId=await _captureVault.saveClip(
        clip,kind:kind,durationMs:duration);
      if(mounted)setState(()=>_hasSavedDraft=false);
    }
    catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text(
          'Recording is available now, but encrypted draft recovery failed.')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordLimit?.cancel();
    _recordTicker?.cancel();
    _toolHintTimer?.cancel();
    unawaited(_amplitudeSubscription?.cancel());
    if(_recording && _mode==_OrbitCaptureMode.voice)unawaited(_audioRecorder.stop());
    unawaited(_audioRecorder.dispose());
    final captured=_capturedClip;
    if(captured!=null)unawaited(_deleteClip(captured));
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
      if(_recording)unawaited(_finishRecording());
      // Android's runtime permission UI temporarily moves the activity to an
      // inactive state while CameraController.initialize() is still waiting
      // for the permission result. Disposing/restarting here creates two
      // competing camera initializations and causes the false error popup.
      if (_cameraInitializationInProgress) {
        return;
      }

      final controller = _controller;
      _controller = null;
      if (controller != null) {
        // Wait for the native camera resource to finish releasing before any
        // subsequent initialization. Android otherwise reports camera-in-use.
        final closing = controller.dispose();
        _cameraDisposalInFlight = closing;
        unawaited(closing.catchError((_){ }));
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _capturedBytes == null && _capturedClip == null &&
        !_isCapturing && !_recording) {
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
    // An Orbit permission/loading popup is useful on first entry, but opening
    // it for every camera flip or Photo/Video switch blocks live camera tools.
    final firstOpen = _controller == null;

    try {
      if (mounted) {
        setState(() {
          _isInitializing = true;
          _cameraError = null;
        });
      }

      if (firstOpen) unawaited(_showOrbitCameraLoadingPopup());

      final disposing = _cameraDisposalInFlight;
      _cameraDisposalInFlight = null;
      if (disposing != null) {
        try { await disposing; } catch (_) {}
      }
      if (!mounted) return;
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
        enableAudio: _mode==_OrbitCaptureMode.video,
      );

      await controller.initialize();
      try{
        _minZoom=await controller.getMinZoomLevel();
        _maxZoom=await controller.getMaxZoomLevel();
        _currentZoom=_minZoom.clamp(_minZoom,_maxZoom).toDouble();
      }catch(_){
        _minZoom=1;_maxZoom=1;_currentZoom=1;
      }

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

  Future<void> _focusAt(Offset point,Size size) async {
    final c=_controller;
    if(c==null || !c.value.isInitialized ||
       size.width<=0 || size.height<=0 || _recording)return;
    final normalized=Offset(
      (point.dx/size.width).clamp(0.0,1.0).toDouble(),
      (point.dy/size.height).clamp(0.0,1.0).toDouble());
    try{await c.setFocusPoint(normalized);}catch(_){}
    try{await c.setExposurePoint(normalized);}catch(_){}
  }

  void _startZoom(ScaleStartDetails details){_zoomStart=_currentZoom;}
  void _zoomCamera(ScaleUpdateDetails details) {
    final c=_controller;
    if(c==null || !c.value.isInitialized ||
       _capturedClip!=null || _capturedBytes!=null || _maxZoom<=_minZoom)return;
    final value=(_zoomStart*details.scale).clamp(_minZoom,_maxZoom).toDouble();
    if((value-_currentZoom).abs()<0.05)return;
    _currentZoom=value;
    unawaited(c.setZoomLevel(value).catchError((_){ }));
  }

  void _showToolHint(String message) {
    if(!mounted)return;
    _toolHintTimer?.cancel();
    setState(() => _toolHint = message);
    _toolHintTimer=Timer(const Duration(seconds:3),(){
      if(mounted)setState(()=>_toolHint=null);
    });
  }

  void _toggleFilterTray() {
    if(_recording || _isCapturing || _publishSheetOpen) return;
    if(_mode!=_OrbitCaptureMode.photo){
      _showToolHint('Photo filters are available in Photo mode.');
      return;
    }
    setState(() {
      _filterTrayOpen = !_filterTrayOpen;
      _toolHint = null;
    });
  }

  void _selectFilter(MomentFilter filter) {
    if(_mode!=_OrbitCaptureMode.photo || _recording || _isCapturing)return;
    setState(() => _selectedFilter = filter);
  }

  Widget _filteredPreview(Widget preview) {
    if(_selectedFilter==MomentFilter.natural ||
       _mode!=_OrbitCaptureMode.photo)return preview;
    // Live GPU preview approximates the selected local photo processor look.
    // The actual encrypted Moment applies the canonical processor in the
    // publish sheet (not by saving a screen capture of this preview).
    final matrix=switch(_selectedFilter){
      MomentFilter.natural => <double>[
        1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
      MomentFilter.warm => <double>[
        1,0,0,0,15, 0,1,0,0,4, 0,0,1,0,-13, 0,0,0,1,0],
      MomentFilter.cool => <double>[
        1,0,0,0,-10, 0,1,0,0,1, 0,0,1,0,16, 0,0,0,1,0],
      MomentFilter.portrait => <double>[
        1.03,0,0,0,7, 0,1.01,0,0,5, 0,0,1,0,5, 0,0,0,1,0],
      MomentFilter.film => <double>[
        .85,.1,.05,0,13, .07,.86,.07,0,7, .05,.13,.82,0,2,
        0,0,0,1,0],
      MomentFilter.night => <double>[
        .68,0,0,0,0, 0,.76,0,0,0, 0,0,.95,0,9, 0,0,0,1,0],
      MomentFilter.soft => <double>[
        .84,.12,.04,0,6, .07,.86,.07,0,6, .06,.15,.79,0,6,
        0,0,0,1,0],
      MomentFilter.vibrant => <double>[
        1.21,-.15,-.06,0,0, -.09,1.18,-.09,0,0,
        -.08,-.13,1.21,0,0, 0,0,0,1,0],
      MomentFilter.blackAndWhite => <double>[
        .299,.587,.114,0,0, .299,.587,.114,0,0,
        .299,.587,.114,0,0, 0,0,0,1,0],
    };
    return ColorFiltered(colorFilter:ColorFilter.matrix(matrix),child:preview);
  }

  Widget _buildFilterTray() {
    return Container(
      key: MomentCameraKeys.filterTray,
      decoration:BoxDecoration(
        color:const Color(0xD9000000),
        border:Border.all(color:const Color(0x2EFFFFFF)),
        borderRadius:BorderRadius.circular(22)),
      padding:const EdgeInsets.fromLTRB(12,12,12,10),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          Text('Filters',style:AppTypography.body.copyWith(
            color:Colors.white,fontWeight:FontWeight.w600)),
          const Spacer(),
          Semantics(button:true,label:'Close filters',
            child:IconButton(
              key:const Key('moment_camera_close_filters'),
              icon:const Icon(Icons.close_rounded,color:Colors.white,size:20),
              onPressed:()=>setState(()=>_filterTrayOpen=false))),
        ]),
        SizedBox(height:48,child:ListView(
          scrollDirection:Axis.horizontal,
          children:[
            for(final filter in MomentFilter.values)
              Padding(
                padding:const EdgeInsets.only(right:8),
                child:Material(
                  color:Colors.transparent,
                  child:InkWell(
                    key:MomentCameraKeys.filter(filter.name),
                    borderRadius:BorderRadius.circular(22),
                    onTap:()=>_selectFilter(filter),
                    child:Container(
                      constraints:const BoxConstraints(minWidth:72),
                      alignment:Alignment.center,
                      padding:const EdgeInsets.symmetric(horizontal:14),
                      decoration:BoxDecoration(
                        gradient:_selectedFilter==filter
                            ? AppColors.primaryGradient:null,
                        color:_selectedFilter==filter
                            ? null:const Color(0xB3000000),
                        borderRadius:BorderRadius.circular(22),
                        border:Border.all(color:_selectedFilter==filter
                            ? Colors.white:const Color(0x85FFFFFF)),
                      ),
                      child:Text(filter.label,maxLines:1,
                        style:AppTypography.body.copyWith(
                          fontSize:12,color:Colors.white,
                          fontWeight:_selectedFilter==filter
                              ?FontWeight.w600:FontWeight.w500)),
                    ),
                  ),
                ),
              ),
          ],
        )),
      ]),
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (_recording || _capturedClip != null || _isCapturing ||
        _isInitializing) return;
    if (controller == null || !controller.value.isInitialized) {
      _showToolHint('Camera is not ready. Please try again.');
      return;
    }
    if (_capturedBytes != null) {
      _showToolHint('Retake the photo to change flash.');
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
    _showToolHint('Flash is not supported by this camera.');
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
    if (_capturedBytes != null || _capturedClip != null || _recording ||
        _isCapturing || _isInitializing) return;
    if (_cameras.length < 2) {
      _showToolHint('No second camera is available.');
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
    if (_capturedBytes != null || _capturedClip != null ||
        _isCapturing || _recording) return;
    if(_mode!=_OrbitCaptureMode.photo){
      _showToolHint('The photo timer is available in Photo mode.');
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
    _showToolHint(_captureDelay == Duration.zero
        ? 'Timer off'
        : 'Timer set to ${_captureDelay.inSeconds} seconds.');
  }

  Future<void> _handleCapturePressed() async {
    if(_recording){
      await _finishRecording();
      return;
    }
    if (_capturedBytes != null || _capturedClip != null) {
      await _retake();
      return;
    }
    if(_mode!=_OrbitCaptureMode.photo){
      _stopWhenStarted=false;
      await _beginRecording();
      return;
    }
    await _captureMoment();
  }

  Future<void> _deleteClip(File file) async {
    try{if(await file.exists())await file.delete();}catch(_){}
  }


  Future<void> _confirmVoiceRecording() async {
    if(!mounted || _recording || _capturedBytes!=null ||
       _capturedClip!=null || _isCapturing ||
       _mode==_OrbitCaptureMode.voice)return;
    await showOrbitPopupModal<void>(
      context:context,
      popupId:'m7_voice_recording_confirmation',
      builder:(dialog)=>OrbitPopupModal(
        key:MomentCameraKeys.voiceConsent,
        title:'Record a Voice Moment?',
        description:'A Voice Moment records audio for up to 60 seconds. '
          'Orbit will request microphone permission when you begin. '
          'Hold the capture button to record and release to stop. '
          'You can review your recording before choosing who sees it.',
        icon:const Icon(Icons.mic_none_rounded,
          size:52,color:AppColors.primaryEnd),
        primaryAction:OrbitPopupPrimaryButton(
          label:'Continue to Voice',
          onPressed:(){
            Navigator.of(dialog).pop();
            if(mounted)unawaited(
              _selectCaptureMode(_OrbitCaptureMode.voice));
          }),
        secondaryAction:OrbitPopupSecondaryButton(
          label:'Not Now',
          onPressed:()=>Navigator.of(dialog).pop(),
        ),
      ),
    );
  }

  Future<void> _selectCaptureMode(_OrbitCaptureMode next) async {
    if(_isCapturing || _recording || _publishSheetOpen ||
       _capturedBytes!=null || _capturedClip!=null || _mode==next)return;
    if(_cameraInitializationInProgress) {
      _showToolHint('Camera is starting. Please try again.');
      return;
    }
    setState((){
      _mode=next;
      _filterTrayOpen=false;
      _toolHint=null;
    });
    if(widget.enableCamera){
      // Video requires microphone access, requested only on explicit selection.
      await _initializeCamera(preferredCamera:_activeCamera);
    }
  }

  Future<void> _beginRecording() async {
    if(_isCapturing || _recording || _capturedClip!=null || !mounted)return;
    try {
      if(_mode==_OrbitCaptureMode.video){
        final camera=_controller;
        if(camera==null || !camera.value.isInitialized)return;
        await camera.startVideoRecording();
      }else {
        if(!await _audioRecorder.hasPermission()){
          throw StateError('Microphone permission is required.');
        }
        final root=await getTemporaryDirectory();
        final path='${root.path}/orbit-m7-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(
          encoder:AudioEncoder.aacLc,bitRate:64000,
          sampleRate:44100,numChannels:1),path:path);
        _capturedClip=File(path);
        await _amplitudeSubscription?.cancel();
        _amplitudeSubscription=_audioRecorder.onAmplitudeChanged(
          const Duration(milliseconds:150)).listen((amplitude){
          if(!mounted || !_recording)return;
          final value=((amplitude.current+52)/52).clamp(0.04,1.0).toDouble();
          setState((){
            _waveform.add(value);
            if(_waveform.length>36)_waveform.removeAt(0);
          });
        });
      }
      _recordStart=DateTime.now();
      if(mounted)setState((){
        _recording=true;
        _elapsedSeconds=0;
      });
      _recordTicker?.cancel();
      _waveform.clear();
      _recordTicker=Timer.periodic(const Duration(seconds:1),(_){
        if(!mounted || !_recording)return;
        setState(()=>_elapsedSeconds=
            DateTime.now().difference(_recordStart!).inSeconds.clamp(0,60));
      });
      if(_stopWhenStarted){
        _stopWhenStarted=false;
        unawaited(_finishRecording());
        return;
      }
      _recordLimit?.cancel();
      _recordLimit=Timer(const Duration(seconds:60),(){
        if(mounted && _recording)unawaited(_finishRecording());
      });
    }catch(_){
      _stopWhenStarted=false;
      final temp=_capturedClip;
      if(temp!=null && _mode==_OrbitCaptureMode.voice){
        await _deleteClip(temp);
        _capturedClip=null;
      }
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Unable to start recording. Check camera and microphone permissions.')));
    }
  }

  Future<void> _finishRecording() async {
    if(!_recording)return;
    _recordLimit?.cancel();
    _recordTicker?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription=null;
    _recording=false;
    final duration=DateTime.now().difference(_recordStart??DateTime.now())
      .inMilliseconds.clamp(1,60000);
    File? clip;
    try{
      if(_mode==_OrbitCaptureMode.video){
        final camera=_controller;
        if(camera==null)return;
        final recorded=await camera.stopVideoRecording();
        clip=File(recorded.path);
      }else{
        final path=await _audioRecorder.stop();
        clip=path==null?null:File(path);
      }
      if(clip==null || !await clip.exists() || await clip.length()<1){
        throw const FormatException('Recorded clip is empty.');
      }
      await _saveClipDraft(clip,
        _mode==_OrbitCaptureMode.video?'video':'audio',duration);
      if(!mounted){await _deleteClip(clip);return;}
      setState((){
        _capturedClip=clip;
        _capturedDurationMs=duration;
      });
    }catch(_){
      // A failed stop/empty-file validation can leave a plaintext native
      // recording behind before it was assigned to the preview state.
      if(clip!=null)await _deleteClip(clip);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Recording could not be completed.')));
    }finally{
      _stopWhenStarted=false;
      if(mounted)setState(()=>_recording=false);
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    if(_isCapturing || _recording || _publishSheetOpen ||
       _capturedBytes!=null || _capturedClip!=null) return;
    if(_mode==_OrbitCaptureMode.voice)return;
    setState(()=>_isCapturing=true);
    try {
      if(_mode==_OrbitCaptureMode.video && widget.galleryPicker==null){
        final clip=await ImagePicker().pickVideo(
          source:ImageSource.gallery,
          maxDuration:const Duration(seconds:60));
        if(clip==null)return;
        if(await clip.length()>500*1024*1024 ||
           await clip.length()==0) {
          throw const FormatException('Video exceeds capture size limits.');
        }
        final info=await CompressVideo().getMediaInfo(clip.path);
        if(info.durationMs<1 || info.durationMs>60000){
          throw const FormatException('Video must be 60 seconds or shorter.');
        }
        if(!mounted)return;
        await _saveClipDraft(File(clip.path),'video',info.durationMs);
        try{await _controller?.pausePreview();}catch(_){}
        if(!mounted)return;
        setState((){
          _capturedClip=File(clip.path);
          _capturedDurationMs=info.durationMs;
        });
        return;
      }
      final picker=widget.galleryPicker;
      Uint8List? bytes;
      if(picker!=null){
        bytes=await picker();
      }else{
        // System gallery selection does not request whole-library access.
        final selected=await ImagePicker().pickImage(
          source:ImageSource.gallery,maxWidth:1440,imageQuality:80);
        if(selected==null)return;
        if(await selected.length()>26*1024*1024){
          throw const FormatException('Image is too large for an encrypted Moment.');
        }
        bytes=await selected.readAsBytes();
      }
      if(bytes==null || bytes.isEmpty)return;
      if(bytes.length>26*1024*1024)throw const FormatException('Photo exceeds 26 MB.');
      if(!mounted)return;
      final controller=_controller;
      try {await controller?.pausePreview();}catch(_){}
      await _savePhotoDraft(bytes);
      if(!mounted)return;
      setState(()=>_capturedBytes=bytes);
      widget.onCaptured?.call(bytes);
    }catch(_){
      if(mounted){
        // The app-wide ScaffoldMessenger already renders Orbit's approved
        // gradient snackbar: no additional color or popup design is used.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('Unable to open this gallery photo.')));
      }
    }finally{
      if(mounted){
        setState(()=>_isCapturing=false);
        // The picker can pause/dispose CameraController. Restart only when
        // selection was cancelled or failed; never while processing a photo.
        if(widget.enableCamera && _capturedBytes==null &&
           _capturedClip==null && _controller==null &&
           !_cameraInitializationInProgress){
          unawaited(_initializeCamera(preferredCamera:_activeCamera));
        }
      }
    }
  }

  Future<void> _captureMoment() async {
    final controller = _controller;
    if (_isCapturing)return;
    if (controller==null || !controller.value.isInitialized) {
      _showToolHint('Camera is not ready. Please try again.');
      return;
    }
    if (controller.value.isTakingPicture)return;

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
      await _savePhotoDraft(bytes);
      if(!mounted)return;
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
    if (!mounted || _isRetaking || _isCapturing || _recording) return;
    _isRetaking=true;
    try {
      _stopWhenStarted=false;
      _filterTrayOpen=false;
      _stickerTrayOpen=false;
      _drawMode=false;
      final old=_capturedClip;
      if(old!=null)await _deleteClip(old);
      try { await _captureVault.clear(); } catch (_) {}
      if(!mounted)return;
      setState(() {
        _capturedBytes=null;
        _capturedClip=null;
        _capturedDurationMs=null;
        _captureClientId=null;
        _hasSavedDraft=false;
        _photoStickers.clear();
        _photoStrokes.clear();
        _activePhotoStroke=null;
        _stickerTrayOpen=false;
        _drawMode=false;
      });
      // A resumed video/voice capture needs a correctly configured camera;
      // a photo only needs its paused preview resumed.
      final controller=_controller;
      if(_mode!=_OrbitCaptureMode.photo && widget.enableCamera) {
        await _initializeCamera(preferredCamera:_activeCamera);
      } else if(controller!=null && controller.value.isInitialized) {
        try {
          await controller.resumePreview();
        } catch (_) {
          if(mounted)await _initializeCamera(preferredCamera:_activeCamera);
        }
      } else if(widget.enableCamera) {
        await _initializeCamera(preferredCamera:_activeCamera);
      }
    } finally {
      _isRetaking=false;
    }
  }
  Future<void> _openEditorTool(String tool) async {
    if(_publishSheetOpen || !mounted)return;
    if(_capturedBytes==null || _mode!=_OrbitCaptureMode.photo){
      _showToolHint('Take a photo first to add stickers or text.');
      return;
    }
    if(tool=='sticker'){
      setState((){
        _drawMode=false;
        _filterTrayOpen=false;
        _stickerTrayOpen=!_stickerTrayOpen;
      });
      return;
    }
    // Keep the existing text editor and secure publishing flow unchanged.
    await _handleSendPressed();
  }

  void _addSticker(String emoji) {
    if(_capturedBytes==null || _photoStickers.length>=20){
      _showToolHint('You can add up to 20 stickers.');
      return;
    }
    setState((){
      final index=_photoStickers.length;
      _photoStickers.add(_CameraSticker(
        ++_stickerCounter,emoji,
        Offset((0.50+(index%4)*0.05).clamp(0.06,0.94).toDouble(),
               (0.42+(index%4)*0.04).clamp(0.06,0.94).toDouble()),
      ));
      _stickerTrayOpen=false;
    });
  }

  void _moveSticker(_CameraSticker sticker,Offset delta,Size canvas) {
    if(canvas.width<=0 || canvas.height<=0 || _exportingPhoto)return;
    setState((){
      sticker.position=Offset(
        (sticker.position.dx+delta.dx/canvas.width).clamp(0.06,0.94).toDouble(),
        (sticker.position.dy+delta.dy/canvas.height).clamp(0.06,0.94).toDouble(),
      );
    });
  }

  void _beginInk(Offset position,Size size){
    if(!_drawMode || _photoStrokes.length>=48 ||
        size.width<=0||size.height<=0)return;
    setState((){
      _activePhotoStroke=_CameraInkStroke(
        _inkColor,[Offset((position.dx/size.width).clamp(0.0,1.0).toDouble(),
                          (position.dy/size.height).clamp(0.0,1.0).toDouble())]);
    });
  }
  void _extendInk(Offset position,Size size){
    if(!_drawMode || _activePhotoStroke==null ||
       _activePhotoStroke!.points.length>=2000 ||
       size.width<=0||size.height<=0)return;
    setState(()=>_activePhotoStroke!.points.add(
      Offset((position.dx/size.width).clamp(0.0,1.0).toDouble(),
             (position.dy/size.height).clamp(0.0,1.0).toDouble())));
  }
  void _endInk(){
    if(_activePhotoStroke==null)return;
    setState((){
      if(_activePhotoStroke!.points.isNotEmpty){
        _photoStrokes.add(_activePhotoStroke!);
      }
      _activePhotoStroke=null;
    });
  }

  Widget _buildStickerTray() => Container(
    key:MomentCameraKeys.stickerTray,
    padding:const EdgeInsets.fromLTRB(12,8,12,12),
    decoration:BoxDecoration(
      color:const Color(0xEE000000),
      border:Border.all(color:const Color(0x55FFFFFF)),
      borderRadius:BorderRadius.circular(24)),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        Text('Stickers',style:AppTypography.body.copyWith(
          color:Colors.white,fontWeight:FontWeight.w600)),
        const Spacer(),
        IconButton(
          key:const Key('moment_camera_sticker_close'),
          onPressed:()=>setState(()=>_stickerTrayOpen=false),
          icon:const Icon(Icons.close_rounded,color:Colors.white)),
      ]),
      SizedBox(height:66,child:ListView(
        scrollDirection:Axis.horizontal,
        children:[
          for(final emoji in _stickerChoices)
            Padding(padding:const EdgeInsets.only(right:8),
              child:InkWell(
                key:Key('moment_camera_sticker_choice_${emoji.runes.first}'),
                onTap:()=>_addSticker(emoji),
                borderRadius:BorderRadius.circular(18),
                child:Container(width:58,alignment:Alignment.center,
                  decoration:BoxDecoration(
                    color:const Color(0x33FFFFFF),
                    borderRadius:BorderRadius.circular(18)),
                  child:Text(emoji,style:const TextStyle(fontSize:32))),
              ),
            ),
        ],
      )),
      const SizedBox(height:6),
      Text('Tap a sticker, then drag it anywhere on your photo.',
        style:AppTypography.body.copyWith(
          fontSize:12,color:Colors.white)),
    ]),
  );

  Widget _buildDrawingPalette() => Container(
    key:MomentCameraKeys.drawPalette,
    padding:const EdgeInsets.fromLTRB(12,8,12,12),
    decoration:BoxDecoration(
      color:const Color(0xEE000000),
      borderRadius:BorderRadius.circular(24)),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        Text('Draw on photo',style:AppTypography.body.copyWith(
          color:Colors.white,fontWeight:FontWeight.w600)),
        const Spacer(),
        TextButton(
          key:const Key('moment_camera_draw_undo'),
          onPressed:_photoStrokes.isEmpty ? null :
            ()=>setState(()=>_photoStrokes.removeLast()),
          child:const Text('Undo',style:TextStyle(color:Colors.white))),
        IconButton(
          key:const Key('moment_camera_draw_done'),
          onPressed:()=>setState((){
            _drawMode=false;
            _endInk();
          }),
          icon:const Icon(Icons.check_rounded,color:Colors.white)),
      ]),
      SizedBox(height:46,child:ListView(
        scrollDirection:Axis.horizontal,
        children:[
          for(var index=0;index<_inkColors.length;index++)
            Padding(padding:const EdgeInsets.only(right:12),
              child:InkWell(
                key:Key('moment_camera_ink_color_$index'),
                customBorder:const CircleBorder(),
                onTap:()=>setState(()=>_inkColor=_inkColors[index]),
                child:Container(width:40,height:40,
                  decoration:BoxDecoration(shape:BoxShape.circle,
                    color:_inkColors[index],
                    border:Border.all(
                      color:_inkColor==_inkColors[index]
                        ? AppColors.primaryEnd:Colors.white,
                      width:_inkColor==_inkColors[index]?3:1)),
                ),
              ),
            ),
        ],
      )),
    ]),
  );

  Future<Uint8List> _photoForPublishing() async {
    final original=_capturedBytes;
    if(original==null)throw StateError('No captured photo.');
    if(_photoStickers.isEmpty && _photoStrokes.isEmpty)return original;
    // Capture only the image and movable overlays, not camera controls.
    // Compositing remains in memory; no unencrypted file is stored.
    setState(()=>_exportingPhoto=true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary=_photoCompositionKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
      if(boundary==null || !boundary.hasSize){
        throw StateError('Photo editor is not ready.');
      }
      final size=boundary.size;
      final ratio=(1440/math.max(size.width,size.height))
        .clamp(1.0,3.0).toDouble();
      final output=await boundary.toImage(pixelRatio:ratio);
      try {
        final data=await output.toByteData(format:ui.ImageByteFormat.png);
        if(data==null)throw StateError('Unable to render edited Moment.');
        return data.buffer.asUint8List();
      }finally{
        output.dispose();
      }
    }finally{
      if(mounted)setState(()=>_exportingPhoto=false);
    }
  }

  Future<void> _handleSendPressed({String initialOverlayText=''}) async {
    final captured = _capturedBytes;
    if(_recording){await _finishRecording();return;}
    if (captured == null && _capturedClip==null) {
      if(_mode==_OrbitCaptureMode.photo) {
        await _captureMoment();
      } else {
        _stopWhenStarted=false;
        await _beginRecording();
      }
      return;
    }
    if (_publishSheetOpen || !mounted) return;
    Uint8List editedPhoto=captured??Uint8List(0);
    if(captured!=null){
      try {
        editedPhoto=await _photoForPublishing();
      } catch (_) {
        _showToolHint('Could not save photo edits. Please try again.');
        return;
      }
    }
    if(!mounted)return;
    // Explicit integrations receive the final photo with graphic edits.
    final legacySend=widget.onSendPressed;
    if(legacySend!=null && captured!=null){
      legacySend(editedPhoto);
      return;
    }
    // Step7:photo-publishing-flow â€” the camera and its permission lifecycle
    // stay mounted under this sheet; no additional camera instance is created.
    _publishSheetOpen = true;
    try {
      await showMomentPublishingSheet(
        context,
        photoBytes: editedPhoto,
        mediaFile:_capturedClip,
        mediaKind:_capturedClip==null?'image':
          (_mode==_OrbitCaptureMode.video?'video':'audio'),
        durationMs:_capturedDurationMs,
        waveformLevels:List<double>.unmodifiable(_waveform),
        initialOverlayText:initialOverlayText,
        initialFilter:_selectedFilter,
        // An authenticated account must never show fabricated Circle names.
        circles: widget.momentAudienceCircles,
        friends: widget.momentAudienceFriends,
        privacyAudience: widget.momentPrivacyAudience,
        publisher: widget.publishMoment,
        privateSaver: widget.privateSaver,
        clientId:_captureClientId,
        onCommitted:widget.enableCamera ? () async {
          await _captureVault.clear();
          _captureClientId=null;
        } : null,
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
                        right: edgePadding + 14,
                        child: _CameraTopButton(
                          key: MomentCameraKeys.filterButton,
                          semanticLabel: 'Camera filters and settings',
                          assetPath: 'assets/icons/filter.svg',
                          onTap: widget.onFilterPressed ?? _toggleFilterTray,
                        ),
                      ),
                      if(!_filterTrayOpen)
                        Positioned(
                          top: 70,
                          right: edgePadding,
                          bottom: 114,
                          width: 68,
                          child: _buildToolColumn(),
                        ),
                      if(_hasSavedDraft && _capturedBytes==null &&
                          _capturedClip==null)
                        Positioned(
                          top:70,
                          left:edgePadding,
                          right:edgePadding+76,
                          child:_buildSavedDraftBanner(),
                        ),
                      if(_filterTrayOpen)
                        Positioned(
                          left:edgePadding,
                          right:edgePadding,
                          bottom:108,
                          child:_buildFilterTray(),
                        ),
                      if(_stickerTrayOpen && _capturedBytes!=null)
                        Positioned(
                          left:edgePadding,right:edgePadding,
                          bottom:108,child:_buildStickerTray(),
                        ),
                      if(_drawMode && _capturedBytes!=null)
                        Positioned(
                          left:edgePadding,right:edgePadding,
                          bottom:108,child:_buildDrawingPalette(),
                        ),
                      if(_toolHint!=null)
                        Positioned(
                          top:72,
                          left:edgePadding,
                          right:edgePadding+80,
                          child:Container(
                            key:MomentCameraKeys.toolHint,
                            padding:const EdgeInsets.all(12),
                            decoration:BoxDecoration(
                              color:const Color(0xD9000000),
                              borderRadius:BorderRadius.circular(18)),
                            child:Text(_toolHint!,
                              textAlign:TextAlign.center,
                              style:AppTypography.body.copyWith(
                                color:Colors.white,fontSize:12)),
                          ),
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
                      if(_mode==_OrbitCaptureMode.voice &&
                          (_recording || _capturedClip!=null) &&
                          _waveform.isNotEmpty)
                         Positioned(
                           left:edgePadding+14,right:edgePadding+14,
                           bottom:194,
                           child:Row(
                             mainAxisAlignment:MainAxisAlignment.center,
                             children:_waveform.map((value)=>Container(
                               width:4,height:5+value*38,
                               margin:const EdgeInsets.symmetric(horizontal:2),
                               decoration:BoxDecoration(
                                 color:Colors.white,
                                 borderRadius:BorderRadius.circular(2)),
                             )).toList(),
                           ),
                         ),
                       if (_recording)
                         Positioned(
                           bottom:100,left:edgePadding,right:edgePadding,
                           child:Center(child:Semantics(
                             liveRegion:true,
                             label:'Recording ${_elapsedSeconds} of 60 seconds',
                             child:Text(
                               'REC  ${(_elapsedSeconds ~/ 60).toString().padLeft(2,'0')}:${(_elapsedSeconds % 60).toString().padLeft(2,'0')} / 01:00',
                               key:const Key('moment_camera_recording_elapsed'),
                               style:AppTypography.body.copyWith(
                                 color:Colors.white,
                                 fontWeight:FontWeight.w600),
                             ),
                           )),
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

  Widget _buildSavedDraftBanner() => Container(
    key:MomentCameraKeys.savedDraftBanner,
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:const Color(0xDE000000),
      borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0x42FFFFFF))),
    child:Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text('Saved Moment',style:AppTypography.body.copyWith(
          color:Colors.white,fontWeight:FontWeight.w600)),
        const SizedBox(height:4),
        Text('Start fresh or resume your encrypted draft.',
          style:AppTypography.body.copyWith(
            fontSize:12,color:Colors.white)),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:TextButton(
            key:MomentCameraKeys.resumeDraft,
            onPressed:_restoringSavedDraft ? null
                : ()=>unawaited(_restoreEncryptedCapture()),
            child:Text(_restoringSavedDraft ? 'Opening...' : 'Resume',
              style:AppTypography.body.copyWith(
                color:Colors.white,fontWeight:FontWeight.w600)),
          )),
          Expanded(child:TextButton(
            key:MomentCameraKeys.discardDraft,
            onPressed:_restoringSavedDraft ? null
                : ()=>unawaited(_discardSavedDraft()),
            child:Text('Discard',style:AppTypography.body.copyWith(
              color:Colors.white,fontWeight:FontWeight.w500)),
          )),
        ]),
      ],
    ),
  );

  Widget _buildCameraBackground() {
    final captured = _capturedBytes;
    if(_capturedClip!=null){
      return ColoredBox(color:Colors.black,
        child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Icon(_mode==_OrbitCaptureMode.video
            ? Icons.videocam_outlined:Icons.mic_none_outlined,
            color:Colors.white,size:62),
          const SizedBox(height:12),
          Text(_mode==_OrbitCaptureMode.video?'Video ready':'Voice ready',
            style:AppTypography.body.copyWith(color:Colors.white)),
        ])));
    }
    if (captured != null) {
      return RepaintBoundary(
        key:_photoCompositionKey,
        child:LayoutBuilder(builder:(context,viewport){
          final size=viewport.biggest;
          return Stack(fit:StackFit.expand,children:[
            _exportingPhoto
              ? Image.memory(captured,key:MomentCameraKeys.capturedPreview,
                  fit:BoxFit.cover,gaplessPlayback:true)
              : _filteredPreview(Image.memory(captured,
                  key:MomentCameraKeys.capturedPreview,
                  fit:BoxFit.cover,gaplessPlayback:true)),
            if(_photoStrokes.isNotEmpty || _activePhotoStroke!=null ||
               _drawMode)
              Positioned.fill(child:IgnorePointer(
                ignoring:!_drawMode,
                child:GestureDetector(
                  behavior:HitTestBehavior.opaque,
                  onPanStart:_drawMode
                    ? (d)=>_beginInk(d.localPosition,size):null,
                  onPanUpdate:_drawMode
                    ? (d)=>_extendInk(d.localPosition,size):null,
                  onPanEnd:_drawMode ? (_)=>_endInk():null,
                  child:CustomPaint(
                    key:MomentCameraKeys.photoInk,
                    painter:_CameraInkPainter([
                      ..._photoStrokes,
                      if(_activePhotoStroke!=null)_activePhotoStroke!,
                    ]),
                  ),
                ),
              )),
            for(final sticker in _photoStickers)
              Positioned(
                left:(sticker.position.dx*size.width-32)
                  .clamp(0.0,math.max(0.0,size.width-64)).toDouble(),
                top:(sticker.position.dy*size.height-32)
                  .clamp(0.0,math.max(0.0,size.height-64)).toDouble(),
                child:GestureDetector(
                  key:MomentCameraKeys.sticker(sticker.id.toString()),
                  behavior:HitTestBehavior.translucent,
                  onPanUpdate:_drawMode ? null
                    : (d)=>_moveSticker(sticker,d.delta,size),
                  onLongPress:_drawMode ? null
                    : ()=>setState(()=>_photoStickers.remove(sticker)),
                  child:SizedBox(width:64,height:64,
                    child:Center(child:Text(sticker.emoji,
                      style:const TextStyle(fontSize:48,
                        fontFamilyFallback:<String>[
                          'Noto Color Emoji','Apple Color Emoji',
                          'Segoe UI Emoji',
                        ])))),
                ),
              ),
          ]);
        }),
      );
    }

    if (!widget.enableCamera) {
      return const ColoredBox(color: Color(0xFF95C7D2));
    }

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return LayoutBuilder(builder:(context,constraints)=>GestureDetector(
        behavior:HitTestBehavior.translucent,
        onTapUp:(tap)=>unawaited(_focusAt(
          tap.localPosition,constraints.biggest)),
        onScaleStart:_startZoom,
        onScaleUpdate:_zoomCamera,
        child:_filteredPreview(_CoverCameraPreview(controller:controller)),
      ));
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
    // After a capture, camera-only controls are not actionable. Keep only
    // available editing tools; Retake returns to the live camera.
    if (_capturedBytes!=null || _capturedClip!=null) {
      return SingleChildScrollView(
        key:MomentCameraKeys.toolsColumn,
        physics:const BouncingScrollPhysics(),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          if (_capturedBytes!=null) ...[
            _CameraToolItem(
              key:MomentCameraKeys.stickersButton,
              semanticLabel:'Open stickers',
              assetPath:'assets/icons/sticker.svg',
              label:'Stickers',
              onTap:widget.onStickersPressed ??
                  ()=>unawaited(_openEditorTool('sticker')),
            ),
            const SizedBox(height:10),
            _CameraToolItem(
              key:MomentCameraKeys.drawButton,
              semanticLabel:'Draw on photo',
              assetPath:'assets/icons/sticker.svg',
              icon:Icons.draw_outlined,
              label:'Draw',
              selected:_drawMode,
              onTap:(){
                setState((){
                  _stickerTrayOpen=false;
                  _filterTrayOpen=false;
                  _drawMode=!_drawMode;
                });
              },
            ),
            const SizedBox(height:10),
            _CameraToolItem(
              key:MomentCameraKeys.textButton,
              semanticLabel:'Add text',
              assetPath:'assets/icons/text.svg',
              label:'Text',
              onTap:widget.onTextPressed ??
                  ()=>unawaited(_openEditorTool('text')),
            ),
          ],
        ]),
      );
    }
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

    return SingleChildScrollView(
      key: MomentCameraKeys.toolsColumn,
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
        _CameraToolItem(
          semanticLabel:'Photo mode',
          selected:_mode==_OrbitCaptureMode.photo,
          assetPath:'assets/icons/flip.svg',
          icon:Icons.photo_camera_outlined,
          label:'Photo',
          onTap:()=>unawaited(_selectCaptureMode(_OrbitCaptureMode.photo)),
        ),
        const SizedBox(height:10),
        _CameraToolItem(
          key: MomentCameraKeys.flashButton,
          semanticLabel: flashSemantic,
          selected:_flashMode!=FlashMode.off,
          assetPath: 'assets/icons/flash.svg',
          label: 'Flash',
          onTap: _toggleFlash,
        ),
        const SizedBox(height: 10),
        _CameraToolItem(
          key:MomentCameraKeys.videoMode,
          semanticLabel:'Video recording mode (60 seconds maximum)',
          selected:_mode==_OrbitCaptureMode.video,
          assetPath:'assets/icons/video.svg',
          label:'Video',
          onTap:()=>unawaited(_selectCaptureMode(_OrbitCaptureMode.video)),
        ),
        const SizedBox(height:10),
        _CameraToolItem(
          key:MomentCameraKeys.voiceMode,
          semanticLabel:'Voice recording mode (60 seconds maximum)',
          selected:_mode==_OrbitCaptureMode.voice,
          assetPath:'assets/icons/flip.svg',
          icon:Icons.mic_none_outlined,
          label:'Voice',
          onTap:()=>unawaited(_confirmVoiceRecording()),
        ),
        const SizedBox(height:10),
        _CameraToolItem(
          key: MomentCameraKeys.galleryButton,
          semanticLabel: _mode==_OrbitCaptureMode.video
            ? 'Choose video up to 60 seconds from gallery'
            : 'Choose photo from gallery',
          assetPath: 'assets/icons/flip.svg',
          icon:Icons.photo_library_outlined,
          label: 'Gallery',
          onTap:_mode==_OrbitCaptureMode.voice?null:()=>unawaited(_pickPhotoFromGallery()),
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
          selected:_captureDelay!=Duration.zero,
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
          onTap: widget.onStickersPressed ?? ()=>unawaited(_openEditorTool('sticker')), 
        ),
        ],
      ),
    );
  }

  Widget _buildBottomControls({required bool compact}) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: _capturedBytes!=null || _capturedClip!=null
              ? Semantics(
                  button:true,
                  label:'Retake Moment',
                  child:InkWell(
                    key:MomentCameraKeys.retakeButton,
                    onTap:()=>unawaited(_retake()),
                    borderRadius:BorderRadius.circular(18),
                    child:Padding(
                      padding:const EdgeInsets.all(4),
                      child:Column(mainAxisSize:MainAxisSize.min,children:[
                        const Icon(Icons.refresh_rounded,
                          color:Colors.white,size:24),
                        Text('Retake',style:AppTypography.body.copyWith(
                          fontSize:12,color:Colors.white,
                          fontWeight:FontWeight.w600)),
                      ]),
                    ),
                  ),
                )
              : _CameraTextButton(
                  key:MomentCameraKeys.textButton,
                  onTap: widget.onTextPressed ??
                      ()=>unawaited(_openEditorTool('text')),
                ),
        ),
        Align(
          alignment: Alignment.center,
          child: _CaptureButton(
            key: MomentCameraKeys.captureButton,
            isBusy: _isCapturing,
            onTap: _handleCapturePressed,
            recordMode:_mode!=_OrbitCaptureMode.photo,
            isRecording:_recording,
            retake:_capturedBytes!=null || _capturedClip!=null,
            onHoldStart:(){
              _stopWhenStarted=false;
              if(!_recording)unawaited(_beginRecording());
            },
            onHoldEnd:(){
              _stopWhenStarted=true;
              if(_recording)unawaited(_finishRecording());
            },
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

class _CameraInkPainter extends CustomPainter {
  const _CameraInkPainter(this.strokes);
  final List<_CameraInkStroke> strokes;
  @override
  void paint(Canvas canvas,Size size) {
    for(final stroke in strokes){
      if(stroke.points.isEmpty)continue;
      final brush=Paint()
        ..color=stroke.color
        ..strokeWidth=4
        ..strokeCap=StrokeCap.round
        ..strokeJoin=StrokeJoin.round
        ..style=PaintingStyle.stroke;
      final first=stroke.points.first;
      if(stroke.points.length==1){
        canvas.drawCircle(
          Offset(first.dx*size.width,first.dy*size.height),2,
          brush..style=PaintingStyle.fill);
        continue;
      }
      final path=Path()..moveTo(first.dx*size.width,first.dy*size.height);
      for(final point in stroke.points.skip(1)){
        path.lineTo(point.dx*size.width,point.dy*size.height);
      }
      canvas.drawPath(path,brush);
    }
  }
  @override
  bool shouldRepaint(covariant _CameraInkPainter old) => true;
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Header actions use the same circular surface and drop shadow as
    // AppCircularIconButton, while retaining the approved custom SVG artwork.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 40,
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
    this.icon,
    this.selected=false,
    super.key,
  });

  final String semanticLabel;
  final String assetPath;
  final IconData? icon;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:selected ? AppColors.primaryGradient:null,
                color:selected ? null:const Color(0x99000000),
                border: Border.all(width: 1, color: const Color(0x66FFFFFF)),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon,size:22,color:Colors.white)
                    : SvgPicture.asset(
                        assetPath,width:22,height:22,
                        colorFilter:const ColorFilter.mode(
                          Colors.white,BlendMode.srcIn),
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
                color: Colors.white,
                shadows:<Shadow>[Shadow(
                  color:Color(0x99000000),blurRadius:6)],
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
  const _CaptureButton({required this.isBusy, required this.onTap,
    this.recordMode=false,this.isRecording=false,this.retake=false,
    this.onHoldStart,this.onHoldEnd,super.key});

  final bool isBusy;
  final VoidCallback onTap;
  final bool recordMode,isRecording,retake;
  final VoidCallback? onHoldStart,onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: retake ? 'Retake Moment' :
        isBusy?'Capturing moment':(isRecording?'Recording moment':
        (recordMode?'Hold to record moment':'Capture moment')),
      child: InkResponse(
        onTap: isBusy ? null : onTap,
        onLongPress:recordMode && !isBusy && !retake ? onHoldStart : null,
        onLongPressUp:recordMode && !isBusy && !retake ? onHoldEnd : null,
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
          child: DecoratedBox(
            decoration:const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child:retake
              ? const Icon(Icons.refresh_rounded,
                  color:Color(0xFF7C3AED),size:36)
              : null,
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
