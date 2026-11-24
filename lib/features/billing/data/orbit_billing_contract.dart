import 'package:flutter/services.dart';
typedef BillingJson=Map<String,dynamic>;
abstract interface class OrbitBillingApi{
  Future<BillingJson> catalog(String provider);
  Future<BillingJson> entitlement();
  Future<BillingJson> context(String provider,String mapping,String requestId);
  Future<BillingJson> verify(String provider,String proof,String requestId,{String? contextId});
}
abstract interface class OrbitBillingStore{
  String get provider;
  Future<List<BillingJson>> products(List<BillingJson> mappings);
  Future<String> purchase(BillingJson context);
  Future<List<BillingJson>> recover({required bool restore});
  Future<void> finish(String proof);
  Future<void> manage();
}
abstract interface class OrbitBillingJournal{
  Future<BillingJson?> read(String owner);
  Future<void> write(String owner,BillingJson value);
  Future<void> clear(String owner);
}
class OrbitNativeBillingStore implements OrbitBillingStore{
  OrbitNativeBillingStore(this.provider);
  @override final String provider;
  static const channel=MethodChannel('orbit/billing');
  static const sandboxBuild=bool.fromEnvironment('ORBIT_BILLING_SANDBOX_TEST_BUILD');
  void _guard(){if(!sandboxBuild)throw StateError('Sandbox test build required.');}
  @override Future<List<BillingJson>> products(List<BillingJson> mappings)async{
    _guard();final r=await channel.invokeListMethod<dynamic>('products',{'mappings':mappings});
    return (r??[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  @override Future<String> purchase(BillingJson context)async{
    _guard();return (await channel.invokeMethod<String>('purchase',context))??'unavailable';
  }
  @override Future<List<BillingJson>> recover({required bool restore})async{
    _guard();final r=await channel.invokeListMethod<dynamic>('recover',{'restore':restore});
    return (r??[]).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
  @override Future<void> finish(String proof)async{_guard();await channel.invokeMethod<void>('finish',{'proof':proof});}
  @override Future<void> manage()async{_guard();await channel.invokeMethod<void>('manage');}
}
