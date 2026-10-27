import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../../data/moment_photo_processor.dart';
import '../../data/orbit_moment_audience_memory.dart';
import '../../../auth/data/orbit_identity_client.dart';
import 'orbit_moment_draft_player.dart';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/models/moment_publish_models.dart';

typedef OrbitPrivatePhotoSaver = Future<void> Function(
  Uint8List photoBytes, void Function(double fraction) onProgress,
);

abstract final class MomentPublishKeys {
  static const sheet = Key('moment_publish_sheet');
  static const review = Key('moment_publish_review');
  static const photoFilter = Key('moment_publish_photo_filter');
  static const overlayText = Key('moment_publish_overlay_text');
  static const photoDrawing = Key('moment_publish_photo_draw');
  static const caption = Key('moment_publish_caption');
  static const chooseAudience = Key('moment_publish_choose_audience');
  static const audience = Key('moment_publish_audience');
  static const submit = Key('moment_publish_submit');
  static const previewSubmit = Key('moment_publish_preview_submit');
  static const progress = Key('moment_publish_progress');
  static const retry = Key('moment_publish_retry');
  static const success = Key('moment_publish_success');
  static const unavailable = Key('moment_publish_unavailable');
  static Key circle(String id) => Key('moment_publish_circle_$id');
}

enum _PublishStep { review, audience, uploading, failed, finished }

/// Opens above the *existing* camera; closing/retaking returns to the captured
/// preview without destroying the camera route or replacing the camera UI.
Future<void> showMomentPublishingSheet(
  BuildContext context, {
  required Uint8List photoBytes,
  File? mediaFile,
  String mediaKind='image',
  int? durationMs,
  List<double> waveformLevels=const [],
  bool enableNativePreview=true,
  String initialOverlayText='',
  MomentFilter initialFilter=MomentFilter.natural,
  required List<MomentAudienceCircle> circles,
  List<MomentAudienceCircle> friends = const [],
  String privacyAudience = 'Nobody',
  MomentPublisher? publisher,
  OrbitPrivatePhotoSaver? privateSaver,
  Future<void> Function()? onCommitted,
  String? clientId,
}) async {
  if(mediaKind=='image' && photoBytes.isEmpty)return;
  if(mediaKind!='image' && (mediaFile==null || !['video','audio'].contains(mediaKind)))return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.97,
      child: MomentPublishSheet(
        photoBytes: photoBytes,
        mediaFile:mediaFile,
        mediaKind:mediaKind,
        durationMs:durationMs,
        waveformLevels:waveformLevels,
        enableNativePreview:enableNativePreview,
        initialOverlayText:initialOverlayText,
        initialFilter: initialFilter,
        circles: circles,
        friends: friends,
        privacyAudience: privacyAudience,
        publisher: publisher,
        privateSaver: privateSaver,
        onCommitted:onCommitted,
        clientId:clientId,
      ),
    ),
  );
}

class MomentPublishSheet extends StatefulWidget {
  const MomentPublishSheet({
    required this.photoBytes,
    required this.circles,
    this.mediaFile,
    this.mediaKind='image',
    this.durationMs,
    this.waveformLevels=const [],
    this.enableNativePreview=true,
    this.initialOverlayText='',
    this.initialFilter=MomentFilter.natural,
    this.friends = const [],
    this.privacyAudience = 'Nobody',
    this.publisher,
    this.privateSaver,
    this.onCommitted,
    this.clientId,
    super.key,
  });

  final Uint8List photoBytes;
  final File? mediaFile;
  final String mediaKind;
  final int? durationMs;
  final List<double> waveformLevels;
  final bool enableNativePreview;
  final String initialOverlayText;
  final MomentFilter initialFilter;
  final List<MomentAudienceCircle> circles;
  final List<MomentAudienceCircle> friends;
  final String privacyAudience;
  final MomentPublisher? publisher;
  final OrbitPrivatePhotoSaver? privateSaver;
  final Future<void> Function()? onCommitted;
  final String? clientId;

  @override
  State<MomentPublishSheet> createState() => _MomentPublishSheetState();
}

class _MomentPublishSheetState extends State<MomentPublishSheet> {
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _overlayText=TextEditingController();
  final TextEditingController _placeLabel=TextEditingController();
  bool _locationConsent=false;
  bool _muteVideo=false;
  bool _dataSaver=false;
  final Set<String> _taggedPeople={};
  final OrbitMomentAudienceMemory _audienceMemory=OrbitMomentAudienceMemory();
  OrbitMomentAudiencePreference? _previousAudience;

  late MomentFilter _filter;
  double _beautyStrength=0;
  bool _drawing=false;
  final List<MomentDrawStroke> _strokes=[];
  List<Offset> _activeStroke=[];
  Uint8List? _editedPreview;
  Timer? _previewDebounce;
  int _previewGeneration=0;
  bool _previewBusy=false;

  Future<Uint8List> _encodeImage() async {
    if(widget.mediaKind!='image')return widget.photoBytes;
    // The M6 stager always re-encodes/strips EXIF before upload. For an
    // unedited photo, avoid a second isolate render so confirmation can
    // begin immediately and the user's original preview stays unchanged.
    if(_filter==MomentFilter.natural && _beautyStrength==0 &&
       _overlayText.text.trim().isEmpty && _strokes.isEmpty && !_dataSaver){
      return widget.photoBytes;
    }
    final edit=MomentPhotoEdit(filter:_filter,
      beautyStrength:_beautyStrength,maxLongSide:_dataSaver?1080:1440,
      text:_overlayText.text,
      strokes:List<MomentDrawStroke>.unmodifiable(_strokes));
    // CPU-heavy image transformations stay off the UI isolate.
    return compute(_renderMomentEdits,(widget.photoBytes,edit));
  }
  void _queuePreview(){
    if(widget.mediaKind!='image')return;
    _previewDebounce?.cancel();
    final generation=++_previewGeneration;
    _previewDebounce=Timer(const Duration(milliseconds:260),()async{
      if(!mounted)return;
      setState(()=>_previewBusy=true);
      try{
        final encoded=await _encodeImage();
        if(mounted && generation==_previewGeneration){
          setState(()=>_editedPreview=encoded);
        }
      }catch(_){
        if(mounted && generation==_previewGeneration){
          setState(()=>_editedPreview=null);
        }
      }finally{
        if(mounted && generation==_previewGeneration){
          setState(()=>_previewBusy=false);
        }
      }
    });
  }
  void _beginStroke(Offset position,Size size){
    if(!_drawing || _strokes.length>=48 ||
        size.width<=0 || size.height<=0)return;
    setState(()=>_activeStroke=[_normalized(position,size)]);
  }
  void _extendStroke(Offset position,Size size){
    if(!_drawing || _activeStroke.isEmpty || _activeStroke.length>=2000)return;
    setState(()=>_activeStroke.add(_normalized(position,size)));
  }
  Offset _normalized(Offset position,Size size)=>Offset(
    (position.dx/size.width).clamp(0.0,1.0).toDouble(),
    (position.dy/size.height).clamp(0.0,1.0).toDouble());
  void _finishStroke(){
    if(_activeStroke.length>1){
      _strokes.add(MomentDrawStroke(List<Offset>.unmodifiable(_activeStroke)));
      _queuePreview();
    }
    if(mounted)setState(()=>_activeStroke=[]);
  }
  final Set<String> _selectedIds = <String>{};
  _PublishStep _step = _PublishStep.review;
  double _progress = 0;
  String? _error;
  bool _busy = false;
  bool _simulated = false;
  bool _savedPrivate = false;
  String _audienceKind = 'only_me';

  @override
  void initState() {
    super.initState();
    _filter=widget.initialFilter;
    if(_filter!=MomentFilter.natural){
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted)_queuePreview();
      });
    }
    if(widget.publisher!=null)unawaited(_loadLastAudience());
    if(widget.initialOverlayText.isNotEmpty){
      _overlayText.text=widget.initialOverlayText.length>80
        ? widget.initialOverlayText.substring(0,80)
        : widget.initialOverlayText;
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted)_queuePreview();
      });
    }
    // Legacy injected publisher tests and preview flows started with Circles.
    // Authenticated M7 always gets the explicit privacyAudience from server.
    if(widget.publisher!=null && widget.circles.isNotEmpty &&
       widget.privacyAudience=='Nobody')_audienceKind='selected_circles';
  }
  Future<void> _loadLastAudience() async {
    try {
      final previous=await _audienceMemory.read();
      if(mounted)setState(()=>_previousAudience=previous);
    }catch(_){
      // Missing secure-storage/session state must never block composition.
    }
  }

  bool get _previousAudienceEligible {
    final previous=_previousAudience;
    if(previous==null || widget.publisher==null)return false;
    switch(previous.kind){
      case 'only_me':return true;
      case 'accepted_friends':
        return widget.privacyAudience=='Selected People' &&
          widget.friends.isNotEmpty;
      case 'selected_friends':
        final active=widget.friends.map((f)=>f.id).toSet();
        return widget.privacyAudience=='Selected People' &&
          previous.targetIds.isNotEmpty &&
          active.containsAll(previous.targetIds);
      case 'selected_circles':
        final active=widget.circles.map((c)=>c.id).toSet();
        return widget.privacyAudience=='My Circle' &&
          previous.targetIds.isNotEmpty &&
          active.containsAll(previous.targetIds);
    }
    return false;
  }

  void _selectPreviousAudience() {
    if(!_previousAudienceEligible)return;
    final previous=_previousAudience!;
    setState((){
      _audienceKind=previous.kind;
      _selectedIds
        ..clear()
        ..addAll(previous.targetIds);
      _taggedPeople.clear();
    });
  }

  String get _previousAudienceLabel {
    switch(_previousAudience?.kind){
      case 'only_me':return 'Only Me';
      case 'accepted_friends':return 'All Friends';
      case 'selected_friends':return 'Selected Friends';
      case 'selected_circles':return 'Selected Circles';
    }
    return '';
  }

  late final String _clientId=widget.clientId??const Uuid().v4();

  // A live repository must inject circles and a publisher together. A missing
  // publisher deliberately never claims a post was published.
  bool get _canPublish => widget.publisher != null;
  bool get _canSavePrivate => widget.privateSaver != null &&
      widget.mediaKind=='image';
  bool get _hasAudience => _canPublish
      ? (_audienceKind=='only_me' ||
        (_audienceKind=='accepted_friends' && widget.friends.isNotEmpty) ||
        _selectedIds.isNotEmpty)
      : _selectedIds.isNotEmpty;
  String get _audienceLabel {
    if(!_canPublish) return _selectedIds.length.toString()+
      (_selectedIds.length==1?' circle':' circles');
    switch(_audienceKind){
      case 'only_me': return 'Only Me';
      case 'accepted_friends': return 'All Friends';
      case 'selected_friends': return _selectedIds.length.toString()+' friends';
      default: return _selectedIds.length.toString()+
        (_selectedIds.length==1?' circle':' circles');
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _overlayText.dispose();
    _placeLabel.dispose();
    _caption.dispose();
    super.dispose();
  }

  String _explainPrivateSaveFailure(Object error) {
    if(error is OrbitIdentityException) {
      if(error.statusCode==401) {
        return 'Your Orbit session expired. Sign in again before saving '
          'encrypted private media. Your capture remains in this review.';
      }
      if(error.statusCode==403) {
        return 'This device is not approved for encrypted media, or Media '
          'access is disabled. Check device approval and M6 Media settings.';
      }
      if(error.statusCode==404 || error.statusCode==405 ||
         error.statusCode==503) {
        return 'The Orbit private-media service is unavailable on the '
          'server. Check that M6 Media is enabled and deployed on Hostinger. '
          'Your capture has not been confirmed as saved.';
      }
      if(error.statusCode==413) {
        return 'This image exceeds the private-media upload limit. '
          'Go back to review and reduce its size.';
      }
      if(error.statusCode==429) {
        return 'Too many media requests were sent. Wait before retrying.';
      }
      if(error.statusCode==null) {
        return 'Could not contact Orbit. Check your internet connection '
          'and retry when the server is reachable.';
      }
      return 'Orbit rejected this private save (HTTP ${error.statusCode}). '
        'Check device trust, account access and M6 Media configuration.';
    }
    if(error is FileSystemException) {
      return 'Private encrypted storage could not be read or written. '
        'Check available device storage before retrying.';
    }
    if(error is FormatException) {
      return 'This photo could not be prepared for encrypted storage. '
        'Return to review and try another image.';
    }
    if(error is StateError) {
      final reason=error.message.toString();
      if(reason.contains('still pending') ||
         reason.contains('still verifying')) {
        return 'The encrypted upload is still waiting for verification. '
          'Your private save is not confirmed. Retry when M6 is available.';
      }
      if(reason.contains('no longer queued')) {
        return 'The previous encrypted upload is no longer in the retry '
          'queue. Return to review before starting another save.';
      }
      if(reason.contains('transport is not configured')) {
        return 'Private media transport is not configured on the server. '
          'Check M6 Media storage settings on Hostinger.';
      }
      if(reason.contains('grant')) {
        return 'Encrypted media was uploaded, but device-only access '
          'could not be confirmed. The save is not complete.';
      }
    }
    return 'Private save could not be confirmed. Return to review to '
      'keep your photo, or retry after checking the M6 Media service.';
  }

  Future<void> _submit({bool previewOnly = false, bool privateOnly = false}) async {
    if (_busy || !mounted) return;
    if (privateOnly && !_canSavePrivate) return;
    if (!privateOnly && !_hasAudience) return;
    if (!previewOnly && !privateOnly && !_canPublish) return;
    if(_locationConsent && _placeLabel.text.trim().isEmpty)return;
    if(_taggedPeople.length>20)return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _simulated = previewOnly;
      _savedPrivate = privateOnly;
      _step = _PublishStep.uploading;
      _progress = 0;
      _error = null;
    });
    try {
      if (privateOnly) {
        // Explicit user action. M6 encrypts and saves to the creator's own
        // trusted device, but does not publish or notify a Circle.
        final edited=widget.mediaKind=='image'?
          await _encodeImage():widget.photoBytes;
        if(!mounted)return;
        await widget.privateSaver!(edited, (fraction) {
          if (!mounted) return;
          setState(() => _progress = fraction.clamp(0.0, 1.0).toDouble());
        });
      } else if (previewOnly) {
        // A clearly labelled *visual preview*: no network request, no post.
        for (final progress in <double>[0.25, 0.55, 0.8, 1]) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
          if (!mounted) return;
          setState(() => _progress = progress);
        }
      } else {
        final edited=widget.mediaKind=='image'?
          await _encodeImage():widget.photoBytes;
        if(!mounted)return;
        final request = MomentPublishRequest(
          photoBytes: edited,
          mediaFile:widget.mediaFile,
          mediaKind:widget.mediaKind,
          durationMs:widget.durationMs,
          muteVideo:_muteVideo,
          dataSaver:_dataSaver,
          waveformLevels:widget.waveformLevels,
          placeLabel:_locationConsent?_placeLabel.text.trim():'',
          locationConsent:_locationConsent && _placeLabel.text.trim().isNotEmpty,
          taggedUserIds:_taggedPeople,
          circleIds: _audienceKind=='selected_circles' ? _selectedIds : const <String>{},
          caption: _caption.text.trim(),
          audienceKind:_audienceKind,
          targetIds:_selectedIds,
          clientId:_clientId,
        );
        final receipt = await widget.publisher!(request, (fraction) {
          if (!mounted) return;
          setState(() => _progress = fraction.clamp(0.0, 1.0).toDouble());
        });
        if (receipt.momentId.trim().isEmpty) {
          throw StateError('The server did not confirm the Moment.');
        }
        // A confirmed server receipt is the success boundary. Writing the
        // optional previous-audience suggestion to OS secure storage must
        // never stall or roll back that successful publish.
        unawaited(_audienceMemory.save(_audienceKind,_selectedIds)
          .catchError((Object _) {}));
      }
      // Publishing receipt or verified private media save is authoritative.
      // Clearing the local capture after success must not invalidate it.
      if(!previewOnly){
        try { await widget.onCommitted?.call(); }catch(_){}
      }
      if (!mounted) return;
      setState(() {
        _step = _PublishStep.finished;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = privateOnly
            ? _explainPrivateSaveFailure(error)
            : 'Your Moment could not be published. Nothing was confirmed as sent.';
        _step = _PublishStep.failed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_busy) return;
    if (_step == _PublishStep.audience || _step == _PublishStep.failed) {
      setState(() => _step = _PublishStep.review);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isCompact = MediaQuery.sizeOf(context).height < 650;
    return PopScope(
      canPop: !_busy,
      child: Material(
        key: MomentPublishKeys.sheet,
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Column(
            children: <Widget>[
              _header(),
              Expanded(
                child: switch (_step) {
                  _PublishStep.review => _review(isCompact),
                  _PublishStep.audience => _audience(),
                  _PublishStep.uploading => _status(isCompact),
                  _PublishStep.failed => _status(isCompact),
                  _PublishStep.finished => _status(isCompact),
                },
              ),
              if(_step==_PublishStep.review && keyboard==0)
                _reviewFooter(),
              if (keyboard == 0)
                SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (_step) {
      _PublishStep.review => 'Review Moment',
      _PublishStep.audience => 'Choose Circles',
      _PublishStep.uploading =>
        _savedPrivate ? 'Saving privately' : 'Publishing Moment',
      _PublishStep.failed => 'Try Again',
      _PublishStep.finished =>
        _savedPrivate ? 'Saved Privately' :
        (_simulated ? 'Preview Complete' : 'Moment Published'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: _step == _PublishStep.review ? 'Return to camera' : 'Back',
            onPressed: _busy ? null : _back,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: AppTypography.smallHeading.copyWith(fontSize: 21),
            ),
          ),
          if (!_busy)
            IconButton(
              tooltip: 'Close publishing flow',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  Widget _review(bool compact) {
    return ListView(
      key: MomentPublishKeys.review,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: compact ? 160 : 255,
            child: widget.mediaKind!='image'
              ? (widget.enableNativePreview
                  ? OrbitMomentDraftPlayer(
                      file:widget.mediaFile!,kind:widget.mediaKind,
                      muted:_muteVideo)
                  : Center(child:Text(
                      widget.mediaKind=='video'
                        ? 'Video ready to encrypt':'Voice ready to encrypt',
                      style:AppTypography.body)))
              : LayoutBuilder(builder:(context,size)=>Stack(
                fit:StackFit.expand,
                children:[
                  Image.memory(_editedPreview??widget.photoBytes,
                    fit:BoxFit.fill,
                    errorBuilder:(_,error,stack)=>const Center(
                      child:Text('Unable to preview this photo'))),
                  if(_drawing)GestureDetector(
                    behavior:HitTestBehavior.opaque,
                    onPanStart:(details)=>_beginStroke(
                      details.localPosition,size.biggest),
                    onPanUpdate:(details)=>_extendStroke(
                      details.localPosition,size.biggest),
                    onPanEnd:(_)=>_finishStroke(),
                    child:CustomPaint(
                      painter:_MomentStrokePainter([
                        ..._strokes,MomentDrawStroke(_activeStroke)]),
                    )),
                  if(_previewBusy)const Align(
                    alignment:Alignment.topRight,
                    child:Padding(padding:EdgeInsets.all(8),
                      child:SizedBox(width:14,height:14,
                        child:CircularProgressIndicator(strokeWidth:2))),
                  ),
                ],
              )),
          ),
        ),
        if(widget.mediaKind=='image'||widget.mediaKind=='video')
          SwitchListTile(
            value:_dataSaver,
            activeColor:AppColors.primaryEnd,
            title:Text('Save mobile data',style:AppTypography.body),
            subtitle:Text(
              widget.mediaKind=='video'?'Lower video bitrate (2 Mbps)':
                'Smaller photo (1080 px)',
              style:AppTypography.bodyMuted),
            onChanged:(value){
              setState(()=>_dataSaver=value);
              _queuePreview();
            },
          ),
        if(widget.mediaKind=='video')SwitchListTile(
          value:_muteVideo,
          activeColor:AppColors.primaryEnd,
          title:Text('Mute video audio',style:AppTypography.body),
          subtitle:Text('Remove audio from the encrypted video export',
            style:AppTypography.bodyMuted),
          onChanged:(value)=>setState(()=>_muteVideo=value),
        ),
        if(widget.mediaKind=='image') ...[
          const SizedBox(height:10),
          SizedBox(height:43,child:ListView(
            key:MomentPublishKeys.photoFilter,
            scrollDirection:Axis.horizontal,
            children:MomentFilter.values.map((filter)=>Padding(
              padding:const EdgeInsets.only(right:8),
              child:ChoiceChip(
                label:Text(filter.label,style:AppTypography.body),
                selected:_filter==filter,
                selectedColor:AppColors.background,
                onSelected:(_){
                  setState(()=>_filter=filter);
                  _queuePreview();
                }),
            )).toList(),
          )),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:Text('Subtle smoothing (optional)',
              style:AppTypography.body)),
            Text(_beautyStrength==0?'Off':'On',style:AppTypography.bodyMuted),
          ]),
          Slider(value:_beautyStrength,min:0,max:0.25,divisions:5,
            activeColor:AppColors.primaryEnd,
            onChanged:(value){
              setState(()=>_beautyStrength=value);
              _queuePreview();
            }),
          const SizedBox(height:8),
          TextField(
            key:MomentPublishKeys.overlayText,
            controller:_overlayText,
            maxLength:80,maxLines:1,
            decoration:const InputDecoration(
              hintText:'Text on photo (optional)'),
            style:AppTypography.body,
            onChanged:(_)=>_queuePreview(),
          ),
          Row(children:[
            OutlinedButton.icon(
              key:MomentPublishKeys.photoDrawing,
              onPressed:()=>setState(()=>_drawing=!_drawing),
              icon:Icon(_drawing?Icons.check:Icons.draw_outlined),
              label:Text(_drawing?'Finish drawing':'Draw on photo')),
            const SizedBox(width:8),
            if(_strokes.isNotEmpty)TextButton(
              onPressed:(){
                setState(()=>_strokes.removeLast());
                _queuePreview();
              },
              child:const Text('Undo')),
          ]),
        ],
        const SizedBox(height: 16),
        TextField(
          key: MomentPublishKeys.caption,
          controller: _caption,
          maxLength: 200,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: 'Add a caption (optional)',
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        if(_canPublish) ...[
          const SizedBox(height:8),
          TextField(
            controller:_placeLabel,
            maxLength:90,maxLines:1,
            style:AppTypography.body,
            decoration:const InputDecoration(
              hintText:'Place (optional; entered manually)'),
            onChanged:(_)=>setState(()=>_locationConsent=false),
          ),
          CheckboxListTile(
              value:_locationConsent,
              title:Text('Include this place for the selected audience',
                style:AppTypography.body),
              subtitle:Text('Optional consent. Orbit does not collect GPS.',
                style:AppTypography.bodyMuted),
              activeColor:AppColors.primaryEnd,
              contentPadding:EdgeInsets.zero,
              onChanged:_placeLabel.text.trim().isEmpty?null:
                (value)=>setState(()=>_locationConsent=value==true),
            ),
          if(widget.friends.isNotEmpty && _audienceKind!='only_me') ...[
            Text('Tag eligible friends (optional)',style:AppTypography.body),
            const SizedBox(height:8),
            Wrap(spacing:6,runSpacing:6,
              children:widget.friends.map((friend)=>FilterChip(
                label:Text(friend.name,style:AppTypography.body),
                selected:_taggedPeople.contains(friend.id),
                onSelected:(selected)=>setState((){
                  if(selected)_taggedPeople.add(friend.id);
                  else _taggedPeople.remove(friend.id);
                }),
              )).toList(),
            ),
          ],
        ],
      ],
    );
  }

  /// Keeps the real audience scope, Publish and safe private-save action
  /// visible while the photo/video editing controls scroll. This is the
  /// existing Orbit button styling, not a second camera or publish flow.
  Widget _reviewFooter(){
    return Padding(
      padding:const EdgeInsets.fromLTRB(20,8,20,8),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        if (_canPublish || !_canSavePrivate)
          OutlinedButton.icon(
            key:MomentPublishKeys.chooseAudience,
            onPressed:()=>setState(()=>_step=_PublishStep.audience),
            icon:const Icon(Icons.people_outline_rounded,size:20),
            label:Text(_hasAudience?'$_audienceLabel selected':'Choose audience'),
            style:OutlinedButton.styleFrom(
              minimumSize:const Size(double.infinity,48),
              foregroundColor:AppColors.primaryEnd,
              side:const BorderSide(color:AppColors.primaryEnd),
              shape:RoundedRectangleBorder(
                borderRadius:BorderRadius.circular(24)),
            ),
          ),
        if(!_canPublish && !_canSavePrivate)
          Text('UI preview only. No upload or notification is sent.',
            style:AppTypography.bodyMuted),
        if(_canSavePrivate && widget.mediaKind=='image')
          Text('Private save needs trusted-device approval and the M6 encrypted media service. It does not publish a Moment.',
            style:AppTypography.bodyMuted),
        const SizedBox(height:8),
        AppPrimaryButton(
          label:_canPublish?'Publish Moment':
            (_canSavePrivate?'Save privately':'Preview publishing flow'),
          enabled:_canPublish?_hasAudience:(_canSavePrivate||_hasAudience),
          onPressed:()=>unawaited(_submit(
            privateOnly:!_canPublish&&_canSavePrivate,
            previewOnly:!_canPublish&&!_canSavePrivate)),
        ),
        if(_canPublish && _canSavePrivate && widget.mediaKind=='image')
          TextButton(
            onPressed:()=>unawaited(_submit(privateOnly:true)),
            child:const Text('Save privately without publishing'),
          ),
        TextButton(onPressed:_back,
          child:const Text('Retake / Back to Camera')),
      ]),
    );
  }

  Widget _audience() {
    final live=_canPublish;
    final choices=live
        ? (_audienceKind=='selected_circles'?widget.circles:widget.friends)
        : widget.circles;
    final types=live
        ? <(String,String)>[
            ('only_me','Only Me'),
            if(widget.privacyAudience=='Selected People') ...[
              ('accepted_friends','All Friends'),
              ('selected_friends','Selected Friends'),
            ],
            if(widget.privacyAudience=='My Circle')
              ('selected_circles','Selected Circles'),
          ] : const <(String,String)>[];
    return Column(
      key:MomentPublishKeys.audience,
      children:<Widget>[
        Padding(
          padding:const EdgeInsets.fromLTRB(20,0,20,12),
          child:Text(live
            ? 'Sharing follows your existing Orbit privacy settings.'
            : 'Sample circles for UI preview only. Nothing is shared.',
            style:AppTypography.bodyMuted),
        ),
        Expanded(child:ListView(
          padding:const EdgeInsets.symmetric(horizontal:20),
          children:<Widget>[
            if(_previousAudienceEligible)Padding(
              padding:const EdgeInsets.only(bottom:12),
              child:TextButton.icon(
                onPressed:_selectPreviousAudience,
                icon:const Icon(Icons.history_rounded),
                label:Text('Choose previous audience: $_previousAudienceLabel'),
              ),
            ),
            for(final type in types)
              Padding(padding:const EdgeInsets.only(bottom:8),
                child:Material(
                  color:AppColors.white,
                  borderRadius:BorderRadius.circular(20),
                  child:RadioListTile<String>(
                    value:type.$1,groupValue:_audienceKind,
                    title:Text(type.$2,style:AppTypography.body),
                    activeColor:AppColors.primaryEnd,
                    onChanged:(v){
                      if(v!=null)setState((){
                        _audienceKind=v;_selectedIds.clear();
                        _taggedPeople.clear();
                      });
                    },
                  ),
                )),
            if(!live || _audienceKind=='selected_circles' ||
                _audienceKind=='selected_friends')
              if(choices.isEmpty)
                Padding(padding:const EdgeInsets.all(20),child:Text(
                  'No eligible members available. Check your existing privacy and Circle settings.',
                  textAlign:TextAlign.center,style:AppTypography.bodyMuted))
              else
                for(final item in choices)Padding(
                  padding:const EdgeInsets.only(bottom:8),
                  child:Material(key:MomentPublishKeys.circle(item.id),
                    color:AppColors.white,
                    borderRadius:BorderRadius.circular(20),
                    child:CheckboxListTile(
                      title:Text(item.name,style:AppTypography.body),
                      value:_selectedIds.contains(item.id),
                      activeColor:AppColors.primaryEnd,
                      shape:RoundedRectangleBorder(
                        borderRadius:BorderRadius.circular(20)),
                      onChanged:(v)=>setState((){
                        if(v==true)_selectedIds.add(item.id);
                        else _selectedIds.remove(item.id);
                      }),
                    ),
                  ),
                ),
          ],
        )),
        Padding(padding:const EdgeInsets.fromLTRB(20,12,20,20),
          child:AppPrimaryButton(
            label:_hasAudience ? 'Continue with '+_audienceLabel : (live?'Choose audience':'Select a circle'),
            enabled:_hasAudience,
            onPressed:()=>setState(()=>_step=_PublishStep.review),
          )),
      ],
    );
  }

  Widget _status(bool compact) {
    final failed = _step == _PublishStep.failed;
    final finished = _step == _PublishStep.finished;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, compact ? 15 : 40, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            finished
                ? Icons.check_circle_outline_rounded
                : failed
                ? Icons.error_outline_rounded
                : Icons.cloud_upload_outlined,
            color: failed ? const Color(0xFFC43C62) : AppColors.primaryEnd,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            failed
                ? (_savedPrivate ? 'Private save interrupted' : 'Publishing interrupted')
                : finished
                ? (_savedPrivate ? 'Photo saved privately' :
                    (_simulated ? 'Preview completed' : 'Your Moment is live'))
                : (_savedPrivate ? 'Encrypting and saving…'
                    : (_simulated ? 'Previewing upload…'
                      : 'Uploading your Moment…')),
            textAlign: TextAlign.center,
            style: AppTypography.smallHeading.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 12),
          if (_step == _PublishStep.uploading)
            Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    key: MomentPublishKeys.progress,
                    value: _progress,
                    color: AppColors.primaryEnd,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_progress * 100).round()}%',
                  style: AppTypography.body,
                ),
              ],
            ),
          if (failed)
            Text(
              _error ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          if (finished)
            Text(
              _savedPrivate
                  ? 'Your encrypted photo is stored for your trusted device. Nothing was shared with a Circle.'
                  : (_simulated
                      ? 'Nothing was uploaded or sent. Connect a publishing service to enable real sharing.'
                      : 'The publishing service confirmed this Moment for $_audienceLabel.'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted,
            ),
          const SizedBox(height: 26),
          if (failed)
            AppPrimaryButton(
              key: MomentPublishKeys.retry,
              label: _savedPrivate ? 'Retry Private Save' : 'Retry Publishing',
              onPressed: () => unawaited(_submit(privateOnly: _savedPrivate)),
            ),
          if (finished)
            AppPrimaryButton(
              key: MomentPublishKeys.success,
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          if (failed)
            TextButton(onPressed: _back, child: const Text('Back to review')),
          if (!finished && _simulated)
            Text(
              'Demo only — no upload or notification is sent.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}


Uint8List _renderMomentEdits((Uint8List,MomentPhotoEdit) args)=>
  MomentPhotoProcessor.render(args.$1,args.$2);

class _MomentStrokePainter extends CustomPainter{
  const _MomentStrokePainter(this.strokes);
  final List<MomentDrawStroke> strokes;
  @override
  void paint(Canvas canvas,Size size){
    final paint=Paint()
      ..color=Colors.white
      ..strokeWidth=3
      ..style=PaintingStyle.stroke
      ..strokeCap=StrokeCap.round;
    for(final stroke in strokes){
      if(stroke.points.length<2)continue;
      final path=Path();
      final first=stroke.points.first;
      path.moveTo(first.dx*size.width,first.dy*size.height);
      for(final p in stroke.points.skip(1)){
        path.lineTo(p.dx*size.width,p.dy*size.height);
      }
      canvas.drawPath(path,paint);
    }
  }
  @override
  bool shouldRepaint(covariant _MomentStrokePainter old)=>true;
}
