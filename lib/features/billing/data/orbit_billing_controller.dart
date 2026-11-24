import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'orbit_billing_contract.dart';

class OrbitBillingController extends ChangeNotifier{
  OrbitBillingController({required this.owner,required this.currentOwner,required this.api,required this.store,required this.journal,this.checkoutEnabled=false});
  final String owner;
  final Future<String?> Function() currentOwner;
  final OrbitBillingApi api;
  final OrbitBillingStore store;
  final OrbitBillingJournal journal;
  final bool checkoutEnabled;
  bool _disposed=false,busy=false;
  String? tier;
  String state='unknown',message='Billing unavailable.';
  bool purchaseEnabled=false;
  bool _readReady=false;
  DateTime? effectiveUntil;
  bool? autoRenew;
  Timer? _expiry;
  Map<String,BillingJson> _mapping={};
  Map<String,String> prices={};
  bool get canManage=>checkoutEnabled&&_readReady&&['active','grace','hold','paused','pending'].contains(state);
  bool canBuy(String selected)=>!busy&&checkoutEnabled&&purchaseEnabled&&_readReady&&['free','expired','revoked'].contains(state)&&_mapping.containsKey(selected)&&prices.containsKey(selected);
  void _emit(){if(!_disposed)notifyListeners();}
  void _unknown(){tier=null;state='unknown';effectiveUntil=null;autoRenew=null;_readReady=false;purchaseEnabled=false;prices={};_mapping={};_expiry?.cancel();}
  Future<void> _bound()async{
    if(_disposed||await currentOwner()!=owner||_disposed){_unknown();throw StateError('Billing account changed.');}
  }
  Future<T> _checked<T>(Future<T> Function() action)async{
    await _bound();final value=await action();await _bound();return value;
  }
  bool _sandbox(BillingJson data)=>data['environment']=='sandbox';
  void _apply(BillingJson e){
    if(!_sandbox(e)||e['revision'] is! int||e['capabilities'] is! Map)throw const FormatException('Invalid billing status.');
    final s=e['state'],t=e['tier'];
    if(!['unknown','free','active','grace','pending','hold','paused','expired','revoked'].contains(s))throw const FormatException('Invalid subscription state.');
    final expiry=DateTime.tryParse(e['effective_until']?.toString()??'')?.toUtc();
    if(t=='lite'||t=='plus'){
      if(!['active','grace'].contains(s)||expiry==null||!expiry.isAfter(DateTime.now().toUtc()))throw const FormatException('Expired subscription evidence.');
    }else if(t!='free'&&t!=null){throw const FormatException('Invalid subscription tier.');}
    else if(['active','grace'].contains(s)){throw const FormatException('Missing paid tier.');}
    if((s=='unknown')!=(t==null))throw const FormatException('Unknown subscription status.');
    tier=checkoutEnabled?t as String?:(t=='free'?'free':null);state=checkoutEnabled?s as String:(t=='free'?s as String:'unknown');effectiveUntil=checkoutEnabled?expiry:null;_readReady=true;
    final renewal=e['auto_renew'];
    if(renewal!=null&&renewal is! bool)throw const FormatException('Invalid renewal state.');
    autoRenew=checkoutEnabled?renewal as bool?:null;
    _expiry?.cancel();
    if(checkoutEnabled&&expiry!=null){_expiry=Timer(expiry.difference(DateTime.now().toUtc()),(){_unknown();message='Subscription status needs refreshing.';_emit();});}
  }
  String _request(String proof,String? context){
    final h=sha256.convert(utf8.encode(['orbit-m19',owner,store.provider,context??'restore',proof].join('|'))).toString();
    return [h.substring(0,8),h.substring(8,12),'4'+h.substring(13,16),'8'+h.substring(17,20),h.substring(20,32)].join('-');
  }
  Future<void> _run(Future<void> Function() action)async{
    if(busy||_disposed)return;busy=true;_emit();
    try{await _bound();await action();}
    catch(_){_unknown();message='Billing could not be verified. Try again or restore purchases.';}
    finally{busy=false;_emit();}
  }
  Future<void> _load()async{
    _unknown();_emit();
    _apply(await _checked(api.entitlement));
    final c=await _checked(()=>api.catalog(store.provider));
    if(!_sandbox(c)||c['production_enabled']!=false||c['provider']!=store.provider||c['products'] is! List)throw const FormatException('Invalid catalog.');
    final rows=<BillingJson>[];
    for(final raw in c['products'] as List){
      if(raw is! Map)continue;final p=Map<String,dynamic>.from(raw);
      if(p['available']!=true||!['lite','plus'].contains(p['tier'])||p['interval']!='month'||p['id'] is! String||p['product_id'] is! String)continue;
      rows.add(p);
    }
    for(final t in ['lite','plus']){
      final matches=rows.where((p)=>p['tier']==t).toList();if(matches.length==1)_mapping[t]=matches.single;
    }
    purchaseEnabled=checkoutEnabled&&c['purchase_enabled']==true;
    if(purchaseEnabled){
      final products=await _checked(()=>store.products(_mapping.values.toList()));
      for(final p in products){
        for(final entry in _mapping.entries){
          if(p['id']==entry.value['id']&&p['product_id']==entry.value['product_id']&&p['base_plan_id']==entry.value['base_plan_id']&&p['price'] is String&&(p['price'] as String).isNotEmpty){
            prices[entry.key]=p['price'] as String;
          }
        }
      }
    }
    message=checkoutEnabled?'Sandbox billing only. Paid benefits are not enabled.':'Billing is not available for live purchases.';
  }
  Future<void> refresh({bool recover=true})=>_run(()async{
    await _load();
    if(checkoutEnabled&&recover){await _recover(false);_apply(await _checked(api.entitlement));}
  });
  Future<void> choose(String selected)=>_run(()async{
    await _load();
    final saved=await _checked(()=>journal.read(owner));
    if(saved!=null&&saved['phase']!='requesting'){
      await _recover(false);
      message='Previous purchase checked. Restore purchases before another checkout.';
      return;
    }
    if(!purchaseEnabled||!['free','expired','revoked'].contains(state)||!prices.containsKey(selected)||!_mapping.containsKey(selected)){
      message='This plan is not available for purchase.';return;
    }
    final mapping=_mapping[selected]!;
    if(saved!=null&&(saved['provider']!=store.provider||saved['mapping']!=mapping['id']||saved['request_id'] is! String)){
      message='Retry the original plan or restore purchases.';return;
    }
    final request=saved?['request_id'] as String? ??const Uuid().v4();
    final checkpoint=<String,dynamic>{'provider':store.provider,'mapping':mapping['id'],'request_id':request,
      'created_at':saved?['created_at']??DateTime.now().toUtc().toIso8601String(),'phase':'requesting'};
    await _checked(()=>journal.write(owner,checkpoint));
    final c=await _checked(()=>api.context(store.provider,mapping['id'] as String,request));
    if(!_sandbox(c)||c['context_id'] is! String||c['account_binding'] is! String||c['product_id']!=mapping['product_id']||c['base_plan_id']!=mapping['base_plan_id']||
       !(DateTime.tryParse(c['expires_at']?.toString()??'')?.isAfter(DateTime.now().toUtc())??false))throw const FormatException('Invalid checkout context.');
    // Persist before crossing the native payment boundary. A crash after
    // this write must recover rather than launch another checkout.
    await _checked(()=>journal.write(owner,{...checkpoint,'phase':'launched','context':c}));
    final outcome=await _checked(()=>store.purchase(c));
    if(outcome=='cancelled'){await _checked(()=>journal.clear(owner));message='Purchase cancelled. The checkout context may remain reserved for 15 minutes.';return;}
    final recovered=await _recover(false);_apply(await _checked(api.entitlement));
    if(outcome=='pending'||!recovered||await _checked(()=>journal.read(owner))!=null){
      message='Purchase pending confirmation or verification. Restore purchases to retry.';
    }else{message='Purchase verified by the billing server.';}
  });
  Future<void> restore()=>_run(()async{
    if(!checkoutEnabled){message='Sandbox test build required.';return;}
    final verified=await _recover(true);await _load();
    message=verified?'Store purchases verified.':'No newly verified purchase; pending purchases can be restored later.';
  });
  Future<bool> _recover(bool restore)async{
    if(!checkoutEnabled)return false;
    final saved=await _checked(()=>journal.read(owner));
    final ctx=saved?['context'];
    final rows=await _checked(()=>store.recover(restore:restore));
    var pending=false,matched=false,verified=false;
    for(final item in rows.take(64)){
      final proof=item['proof'];if(proof is! String||proof.isEmpty||proof.length>65536)continue;
      final same=ctx is Map&&saved?['provider']==store.provider&&item['binding']==ctx['account_binding']&&item['product_id']==ctx['product_id'];
      if(same)matched=true;
      if(item['state']=='pending'){pending=true;continue;}
      if(item['state']!='purchased')continue;
      final contextId=same?ctx['context_id'] as String:null;
      try{
        final result=await _checked(()=>api.verify(store.provider,proof,_request(proof,contextId),contextId:contextId));
        final e=result['entitlement'];
        if(e is! Map||!['verified','pending'].contains(result['status']))throw const FormatException('Invalid verification result.');
        _apply(Map<String,dynamic>.from(e));
        if(result['status']=='verified'&&result['finish_permitted']==true){
          await _checked(()=>store.finish(proof));verified=true;if(same)await _checked(()=>journal.clear(owner));
        }else{pending=true;}
      }catch(_){await _bound();pending=true;}
    }
    if(restore&&saved!=null&&!matched&&!pending){
      final cutoff=ctx is Map?DateTime.tryParse(ctx['expires_at']?.toString()??''):DateTime.tryParse(saved['created_at']?.toString()??'')?.add(const Duration(minutes:15));
      final expired=cutoff!=null&&!cutoff.isAfter(DateTime.now().toUtc());
      if(expired)await _checked(()=>journal.clear(owner));
    }
    if(pending)message='Purchase pending verification. Restore purchases to retry.';
    return verified&&!pending;
  }
  /// Check local identity without a provider or backend request. Never show
  /// the previous account's verified plan after account changes.
  Future<void> revalidateOwner()async{
    if(_disposed)return;
    try{await _bound();}
    catch(_){if(!_disposed){_unknown();message='Billing account changed. Reopen Subscription.';_emit();}}
  }
  Future<void> manage()=>_run(()async{await _load();if(!canManage){message='Subscription management is unavailable.';return;}await _checked(store.manage);});
  @override void dispose(){_disposed=true;_expiry?.cancel();super.dispose();}
}
