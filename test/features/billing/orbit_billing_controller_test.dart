import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/billing/data/orbit_billing_contract.dart';
import 'package:orbit_ui/features/billing/data/orbit_billing_controller.dart';

BillingJson sampleEntitlement({String? tier='free',String state='free',String environment='sandbox'})=>{'environment':environment,'tier':tier,'state':state,'revision':1,'capabilities':{},'effective_until':tier=='lite'||tier=='plus'?DateTime.now().toUtc().add(const Duration(days:1)).toIso8601String():null};
class Api implements OrbitBillingApi{
  BillingJson status=sampleEntitlement();
  bool verifyFails=false,enabled=true;
  int contexts=0,verifies=0;
  final requests=<String>[];
  @override Future<BillingJson> catalog(String provider)async=>{'environment':'sandbox','production_enabled':false,'provider':provider,'purchase_enabled':enabled,'products':[{'id':'mapped','tier':'lite','product_id':'orbit.lite','base_plan_id':'monthly','interval':'month','available':true}]};
  @override Future<BillingJson> entitlement()async=>status;
  @override Future<BillingJson> context(String provider,String mapping,String requestId)async{
    contexts++;
    return {'environment':'sandbox','context_id':'context','account_binding':'binding','product_id':'orbit.lite','base_plan_id':'monthly','expires_at':DateTime.now().toUtc().add(const Duration(minutes:15)).toIso8601String()};
  }
  @override Future<BillingJson> verify(String provider,String proof,String requestId,{String? contextId})async{
    verifies++;requests.add(requestId);if(verifyFails)throw StateError('offline');
    status={'environment':'sandbox','tier':'lite','state':'active','revision':2,'capabilities':{},'effective_until':DateTime.now().toUtc().add(const Duration(days:1)).toIso8601String()};
    return {'status':'verified','finish_permitted':true,'entitlement':status};
  }
}
class Store implements OrbitBillingStore{
  @override String get provider=>'google';
  String outcome='purchased';
  int purchases=0,finishes=0,restores=0,manages=0;
  List<BillingJson> receipts=[];
  Future<void> Function()? onPurchase;
  @override Future<List<BillingJson>> products(List<BillingJson> mappings)async=>[{'id':'mapped','product_id':'orbit.lite','base_plan_id':'monthly','price':'PKR 500'}];
  @override Future<String> purchase(BillingJson context)async{
    purchases++;await onPurchase?.call();
    if(outcome=='purchased')receipts=[{'proof':'proof','binding':'binding','product_id':'orbit.lite','state':'purchased'}];
    return outcome;
  }
  @override Future<List<BillingJson>> recover({required bool restore})async{if(restore)restores++;return receipts;}
  @override Future<void> finish(String proof)async{finishes++;}
  @override Future<void> manage()async{manages++;}
}
class Journal implements OrbitBillingJournal{
  final values=<String,BillingJson>{};
  @override Future<BillingJson?> read(String owner)async=>values[owner];
  @override Future<void> write(String owner,BillingJson value)async{values[owner]=value;}
  @override Future<void> clear(String owner)async{values.remove(owner);}
}
void main(){
  late Api api;late Store store;late Journal journal;late String owner;
  OrbitBillingController controller({bool enabled=true}){
    final c=OrbitBillingController(owner:'a',currentOwner:()async=>owner,api:api,store:store,journal:journal,checkoutEnabled:enabled);
    addTearDown(c.dispose);return c;
  }
  setUp((){api=Api();store=Store();journal=Journal();owner='a';});
  test('normal build cannot launch or display paid sandbox tier',()async{
    final c=controller(enabled:false);await c.refresh();await c.choose('lite');
    expect(c.canBuy('lite'),false);expect(store.purchases,0);expect(api.contexts,0);
  });
  test('localized mapped price and verified purchase only',()async{
    final c=controller();await c.refresh();expect(c.prices['lite'],'PKR 500');expect(c.canBuy('lite'),true);
    await c.choose('lite');expect(c.tier,'lite');expect(store.finishes,1);expect(journal.values,isEmpty);
    await c.manage();expect(store.manages,1);
  });
  test('failed verification leaves checkpoint; recovery reuses request',()async{
    final c=controller();api.verifyFails=true;await c.choose('lite');
    expect(c.tier,'free');expect(store.finishes,0);expect(journal.values['a'],isNotNull);
    final first=api.requests.single;
    final restarted=controller();api.verifyFails=false;await restarted.refresh();
    expect(api.requests.last,first);expect(restarted.tier,'lite');expect(store.purchases,1);expect(store.finishes,1);
  });
  test('pending and cancelled purchase never grant entitlement',()async{
    final c=controller();store.outcome='pending';await c.choose('lite');
    expect(c.tier,'free');expect(journal.values['a'],isNotNull);
    await c.choose('lite');expect(store.purchases,1);expect(store.finishes,0);
    journal.values.clear();store.outcome='cancelled';await c.choose('lite');
    expect(journal.values,isEmpty);expect(c.tier,'free');
  });
  test('account switch during checkout never submits or finishes proof',()async{
    final c=controller();store.onPurchase=()async{owner='b';};await c.choose('lite');
    expect(c.tier,isNull);expect(api.verifies,0);expect(store.finishes,0);
    expect(journal.values['a'],isNotNull);expect(journal.values['b'],isNull);
  });
  test('malformed environment never activates paid status',()async{
    final c=controller();api.status={'environment':'production','tier':'lite','state':'active','revision':1,'capabilities':{}};
    await c.refresh();expect(c.tier,isNull);expect(c.canBuy('lite'),false);
  });
}
