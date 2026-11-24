import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/data/orbit_identity_client.dart';
import 'orbit_billing_contract.dart';

class OrbitBillingRepository implements OrbitBillingApi{
  OrbitBillingRepository(this.owner,{OrbitIdentityClient? identity}):_identity=identity??OrbitIdentityClient.instance;
  final String owner;
  final OrbitIdentityClient _identity;
  Future<BillingJson> _call(String method,String path,[Map<String,Object?>? body])async{
    final r=await _identity.billingRequest(owner,method,path,body:body);
    final data=r['data'];if(data is! Map)throw const FormatException('Invalid billing response.');
    return Map<String,dynamic>.from(data);
  }
  @override Future<BillingJson> catalog(String provider)=>_call('GET','/billing/catalog?provider=$provider');
  @override Future<BillingJson> entitlement()=>_call('GET','/billing/entitlement');
  @override Future<BillingJson> context(String provider,String mapping,String requestId)=>_call('POST','/billing/purchase-context',
    {'provider':provider,'product_mapping_id':mapping,'client_request_id':requestId});
  @override Future<BillingJson> verify(String provider,String proof,String requestId,{String? contextId})=>_call('POST','/billing/verify',
    {'provider':provider,'proof':proof,'client_request_id':requestId,'mode':contextId==null?'restore':'purchase',if(contextId!=null)'context_id':contextId});
}
/// Store retains transaction proofs; only small checkout context persisted.
class OrbitSecureBillingJournal implements OrbitBillingJournal{
  OrbitSecureBillingJournal({FlutterSecureStorage? storage}):_storage=storage??const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  String _key(String owner)=>'orbit-m19-checkout-v1-'+sha256.convert(utf8.encode(owner)).toString();
  @override Future<BillingJson?> read(String owner)async{
    final raw=await _storage.read(key:_key(owner));if(raw==null)return null;
    final v=jsonDecode(raw);if(v is! Map||v['owner']!=owner)throw const FormatException('Invalid checkout checkpoint.');
    return Map<String,dynamic>.from(v);
  }
  @override Future<void> write(String owner,BillingJson value)async{
    final raw=jsonEncode({...value,'owner':owner});if(raw.length>8192)throw const FormatException('Invalid checkout checkpoint.');
    await _storage.write(key:_key(owner),value:raw);
  }
  @override Future<void> clear(String owner)=>_storage.delete(key:_key(owner));
}
