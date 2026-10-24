import 'dart:async';
import 'dart:typed_data';

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
  required List<MomentAudienceCircle> circles,
  List<MomentAudienceCircle> friends = const [],
  String privacyAudience = 'Nobody',
  MomentPublisher? publisher,
  OrbitPrivatePhotoSaver? privateSaver,
}) async {
  if (photoBytes.isEmpty) return;
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
        circles: circles,
        friends: friends,
        privacyAudience: privacyAudience,
        publisher: publisher,
        privateSaver: privateSaver,
      ),
    ),
  );
}

class MomentPublishSheet extends StatefulWidget {
  const MomentPublishSheet({
    required this.photoBytes,
    required this.circles,
    this.friends = const [],
    this.privacyAudience = 'Nobody',
    this.publisher,
    this.privateSaver,
    super.key,
  });

  final Uint8List photoBytes;
  final List<MomentAudienceCircle> circles;
  final List<MomentAudienceCircle> friends;
  final String privacyAudience;
  final MomentPublisher? publisher;
  final OrbitPrivatePhotoSaver? privateSaver;

  @override
  State<MomentPublishSheet> createState() => _MomentPublishSheetState();
}

class _MomentPublishSheetState extends State<MomentPublishSheet> {
  final TextEditingController _caption = TextEditingController();
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
    // Legacy injected publisher tests and preview flows started with Circles.
    // Authenticated M7 always gets the explicit privacyAudience from server.
    if(widget.publisher!=null && widget.circles.isNotEmpty &&
       widget.privacyAudience=='Nobody')_audienceKind='selected_circles';
  }
  final String _clientId = const Uuid().v4();

  // A live repository must inject circles and a publisher together. A missing
  // publisher deliberately never claims a post was published.
  bool get _canPublish => widget.publisher != null;
  bool get _canSavePrivate => widget.privateSaver != null;
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
    _caption.dispose();
    super.dispose();
  }

  Future<void> _submit({bool previewOnly = false, bool privateOnly = false}) async {
    if (_busy || !mounted) return;
    if (privateOnly && !_canSavePrivate) return;
    if (!privateOnly && !_hasAudience) return;
    if (!previewOnly && !privateOnly && !_canPublish) return;
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
        await widget.privateSaver!(widget.photoBytes, (fraction) {
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
        final request = MomentPublishRequest(
          photoBytes: widget.photoBytes,
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
      }
      if (!mounted) return;
      setState(() {
        _step = _PublishStep.finished;
        _progress = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = privateOnly
            ? 'Private save was interrupted. Any encrypted draft stays queued for a safe retry.'
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
            child: Image.memory(
              widget.photoBytes,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => const ColoredBox(
                color: Colors.black12,
                child: Center(child: Text('Unable to preview this photo')),
              ),
            ),
          ),
        ),
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
        const SizedBox(height: 6),
        if (!_canSavePrivate)
          Text(
            'Choose who can see your encrypted Moment.',
            style: AppTypography.bodyMuted,
          ),
        const SizedBox(height: 10),
        if (!_canSavePrivate)
        OutlinedButton.icon(
          key: MomentPublishKeys.chooseAudience,
          onPressed: () => setState(() => _step = _PublishStep.audience),
          icon: const Icon(Icons.people_outline_rounded, size: 20),
          label: Text(
            _hasAudience ? '$_audienceLabel selected' : 'Choose audience',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: AppColors.primaryEnd,
            side: const BorderSide(color: AppColors.primaryEnd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_canPublish && !_canSavePrivate)
          Padding(
            key: MomentPublishKeys.unavailable,
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'UI preview only. No account circles or publishing service are connected yet. '
              'Previewing does not upload or notify anyone.',
              style: AppTypography.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        if (_canSavePrivate)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Save this photo as private encrypted media. Only your trusted '
              'device receives its key; it is not published to any Circle.',
              style: AppTypography.bodyMuted,
            ),
          ),
        AppPrimaryButton(
          label: _canPublish ? 'Publish Moment'
              : (_canSavePrivate ? 'Save privately' : 'Preview publishing flow'),
          enabled: _canPublish ? _hasAudience : (_canSavePrivate || _hasAudience),
          onPressed: () => unawaited(_submit(
            privateOnly: !_canPublish && _canSavePrivate,
            previewOnly: !_canPublish && !_canSavePrivate,
          )),
        ),
        if(_canPublish && _canSavePrivate)
          TextButton(
            onPressed:()=>unawaited(_submit(privateOnly:true)),
            child:const Text('Save privately without publishing'),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _back,
          child: const Text('Retake / Back to Camera'),
        ),
      ],
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
