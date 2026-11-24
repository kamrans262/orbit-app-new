import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../auth/data/orbit_identity_client.dart';
import '../../profile/presentation/screens/subscription_screen.dart';
import '../data/orbit_billing_contract.dart';
import '../data/orbit_billing_controller.dart';
import '../data/orbit_billing_repository.dart';

/// Uses the approved SubscriptionScreen rather than a second paywall.
class OrbitLiveSubscriptionScreen extends StatefulWidget{
  const OrbitLiveSubscriptionScreen({super.key,this.controller});
  final OrbitBillingController? controller;
  @override State<OrbitLiveSubscriptionScreen> createState()=>_OrbitLiveSubscriptionScreenState();
}
class _OrbitLiveSubscriptionScreenState extends State<OrbitLiveSubscriptionScreen> with WidgetsBindingObserver{
  OrbitBillingController? _controller;
  Timer? _timer;
  bool _initializing=true;
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_init());
  }
  Future<void> _init()async{
    final identity=OrbitIdentityClient.instance;
    try{
      final injected=widget.controller;
      final owner=injected?.owner??await identity.currentLocalSocialOwner();
      if(!mounted)return;
      if(owner!=null&&(injected!=null||Platform.isIOS||Platform.isAndroid)){
        final c=injected??OrbitBillingController(owner:owner,currentOwner:identity.currentLocalSocialOwner,
          api:OrbitBillingRepository(owner),store:OrbitNativeBillingStore(Platform.isIOS?'apple':'google'),
          journal:OrbitSecureBillingJournal(),checkoutEnabled:kDebugMode&&OrbitNativeBillingStore.sandboxBuild);
        _controller=c;c.addListener(_changed);await c.refresh();
      }
    }finally{
      if(mounted){setState(()=>_initializing=false);
        _timer=Timer.periodic(const Duration(seconds:15),(_){final c=_controller;if(c!=null&&WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed)unawaited(c.refresh());});
      }
    }
  }
  void _changed(){if(mounted)setState((){});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){final c=_controller;if(c!=null)unawaited(c.refresh());}
  }
  OrbitSubscriptionTier? _tier(String? t)=>switch(t){'free'=>OrbitSubscriptionTier.free,'lite'=>OrbitSubscriptionTier.lite,'plus'=>OrbitSubscriptionTier.plus,_=>null};
  @override Widget build(BuildContext context){
    final c=_controller,tier=_tier(_controller?.tier);
    String? status;
    if(c!=null&&tier!=null){
      status=tier==OrbitSubscriptionTier.free?'Free · '+c.state:'Sandbox '+tier.label+' · '+c.state;
      if(c.effectiveUntil!=null)status+=' · through '+c.effectiveUntil!.toLocal().toIso8601String().substring(0,10);
    }
    return SubscriptionScreen(liveBilling:true,currentTier:tier,statusText:status,
      externalBusy:_initializing||(c?.busy??false),storePrices:c?.prices??const {},
      billingNotice:c?.message??'Billing is unavailable. Live purchases are disabled.',
      allowedPurchaseTiers:{if(c?.canBuy('lite')==true)'lite',if(c?.canBuy('plus')==true)'plus'},
      canManage:c?.canManage??false,restoreEnabled:c?.checkoutEnabled??false,
      onPlanRequested:(tier)async{await c?.choose(tier.name);},
      onRestoreRequested:()async{await c?.restore();},onManageRequested:()async{await c?.manage();});
  }
  @override void dispose(){
    _timer?.cancel();WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_changed);if(widget.controller==null)_controller?.dispose();super.dispose();
  }
}
