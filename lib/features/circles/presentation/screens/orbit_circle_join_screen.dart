import 'package:flutter/material.dart';

import '../widgets/orbit_circle_confirmation.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/navigation/app_fade_slide_page_route.dart';
import '../../../auth/data/orbit_identity_client.dart';
import '../../data/orbit_circle_repository.dart';
import 'orbit_circle_qr_scan_screen.dart';

/// M5 code admission for onboarding and authenticated users. A QR or URL is
/// only a bearer hint: the server verifies recipient eligibility on preview,
/// and the user separately confirms before redeem.
class OrbitCircleJoinScreen extends StatefulWidget {
  const OrbitCircleJoinScreen({super.key, this.repository, this.onJoined});
  final OrbitCircleRepository? repository;
  final VoidCallback? onJoined;

  @override
  State<OrbitCircleJoinScreen> createState() => _OrbitCircleJoinScreenState();
}

class _OrbitCircleJoinScreenState extends State<OrbitCircleJoinScreen> {
  late final OrbitCircleRepository _repo = widget.repository ?? OrbitCircleRepository();
  final _code = TextEditingController();
  bool _busy = false;
  DateTime? _rateLimitedUntil;
  String? _error;
  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _scan() async {
    if (_busy || _withinCooldown()) return;
    final code = await Navigator.of(context).push<String>(
      AppFadeSlidePageRoute<String>(builder: (_) => OrbitCircleQrScanScreen(repository:_repo)));
    if (!mounted || code == null) return;
    _code.text = code;
    await _join();
  }

  bool _withinCooldown() {
    if (_rateLimitedUntil == null || !DateTime.now().isBefore(_rateLimitedUntil!)) return false;
    if (mounted) setState(() => _error =
        'Too many invitation checks. Please try again in about a minute.');
    return true;
  }

  Future<void> _join() async {
    if (_busy || _withinCooldown()) return;
    FocusScope.of(context).unfocus();
    String code;
    try { code = _repo.validateCode(_code.text); }
    on FormatException catch (e) { setState(()=>_error=e.message); return; }
    setState(() { _busy=true; _error=null; });
    try {
      final preview = await _repo.previewCode(code);
      if (!mounted) return;
      final circleName = preview['circle_name'];
      if (circleName is! String || circleName.trim().isEmpty) {
        throw const FormatException('The invitation cannot be verified.');
      }
      final approved = await showOrbitCircleConfirmation(
        context: context,
        title: 'Join private Circle?',
        description: 'Join "$circleName"? Membership never enables your '
          'location, presence, photos or messages automatically.',
        confirmLabel: 'Join Circle',
      );
      if (approved != true || !mounted) return;
      await _repo.redeemCode(code);
      if (!mounted) return;
      if (widget.onJoined != null) {
        widget.onJoined!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (e is OrbitIdentityException && e.statusCode == 429) {
        _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 65));
      }
      if(mounted) setState(()=>_error=e is OrbitIdentityException && e.statusCode==429
        ? 'Too many invitation checks. Please try again in about a minute.'
        : e is OrbitIdentityException ? e.message
        : e is FormatException ? e.message
        : 'Invitation unavailable. Check the code or reconnect.');
    } finally {
      if (mounted) setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    body:SafeArea(child:Column(children:[
      const Padding(
        padding:EdgeInsets.fromLTRB(20,20,20,0),
        child:AppScreenHeader(title:'Join with Code'),
      ),
      const SizedBox(height:20),
      Expanded(child:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Enter the private Circle invitation code you received.',
        style:TextStyle(fontFamily:AppTypography.fontFamily,fontSize:14)),
      const SizedBox(height:20),
      TextField(
        key:const Key('m5_join_code_field'),
        controller:_code,
        autocorrect:false,
        textCapitalization:TextCapitalization.none,
        keyboardType:TextInputType.visiblePassword,
        textInputAction:TextInputAction.done,
        onSubmitted:(_)=>_join(),
        decoration:InputDecoration(
          labelText:'Circle invitation code',
          filled:true,fillColor:Colors.white,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
        ),
      ),
      const SizedBox(height:14),
      if(_error!=null)Padding(padding:const EdgeInsets.only(bottom:14),
        child:Text(_error!,style:const TextStyle(color:Color(0xFFB91C1C),
          fontFamily:AppTypography.fontFamily))),
      FilledButton.icon(
        key:const Key('m5_join_verify'),
        onPressed:_busy ? null : _join,
        icon:_busy ? const SizedBox.square(dimension:18,
          child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
          :const Icon(Icons.check_circle_outline),
        label:const Text('Verify & Join'),
      ),
      const SizedBox(height:8),
      TextButton.icon(
        key:const Key('m5_join_scan'),
        onPressed:_busy ? null : _scan,
        icon:const Icon(Icons.qr_code_scanner),
        label:const Text('Scan invitation QR'),
      ),
    ])),
  ])),
  );
}
