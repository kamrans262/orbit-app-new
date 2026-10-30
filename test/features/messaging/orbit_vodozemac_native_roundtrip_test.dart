import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_vodozemac_ffi.dart';

void main(){
  final native=OrbitVodozemacNative.tryLoad();

  test('Native audited Olm peer sessions exchange authenticated forward-secret messages',
      () {
    final bridge=native!;
    final key=base64Encode(List<int>.generate(32,(i)=>i+1));
    Map<String,dynamic> request(String op,Map<String,Object?> fields)=>
      bridge.invoke({'op':op,'pickle_key_b64':key,...fields});

    final a=request('account_create',{'device_id':'alice-device'});
    final b=request('account_create',{'device_id':'bob-device'});
    final bOneTime=b['one_time_prekeys'] as List;
    final first=request('session_outbound',{
      'account_pickle':a['account_pickle'],
      'recipient_curve_b64':b['signed_prekey_x25519'],
      'recipient_one_time_b64':
        (bOneTime.first as Map)['public_x25519'],
    });
    final encrypted=request('session_encrypt',{
      'session_pickle':first['session_pickle'],
      'plaintext_b64':base64Encode(utf8.encode('Alice secret')),
    });
    expect(encrypted['message_type'],0);
    final received=request('session_inbound',{
      'account_pickle':b['account_pickle'],
      'sender_curve_b64':a['signed_prekey_x25519'],
      'message_type':encrypted['message_type'],
      'ciphertext_b64':encrypted['ciphertext_b64'],
    });
    expect(utf8.decode(base64Decode(received['plaintext_b64'] as String)),
      'Alice secret');
    final reply=request('session_encrypt',{
      'session_pickle':received['session_pickle'],
      'plaintext_b64':base64Encode(utf8.encode('Bob reply')),
    });
    final decrypted=request('session_decrypt',{
      'session_pickle':encrypted['session_pickle'],
      'message_type':reply['message_type'],
      'ciphertext_b64':reply['ciphertext_b64'],
    });
    expect(utf8.decode(base64Decode(decrypted['plaintext_b64'] as String)),
      'Bob reply');
  },skip:native==null);

  test('Native Megolm sender-key rotation makes old group key unusable',
      (){
    final bridge=native!;
    final key=base64Encode(List<int>.generate(32,(i)=>i+1));
    Map<String,dynamic> request(String op,Map<String,Object?> fields)=>
      bridge.invoke({'op':op,'pickle_key_b64':key,...fields});

    final older=request('group_create',{});
    final oldInbound=request('group_import',{
      'session_key':older['session_key'],
    });
    final first=request('group_encrypt',{
      'group_pickle':older['group_pickle'],
      'plaintext_b64':base64Encode(utf8.encode('Old roster')),
    });
    final firstRead=request('group_decrypt',{
      'inbound_pickle':oldInbound['inbound_pickle'],
      'message_b64':first['message_b64'],
    });
    expect(utf8.decode(base64Decode(firstRead['plaintext_b64'] as String)),
      'Old roster');
    final rotated=request('group_create',{});
    expect(rotated['session_id'],isNot(older['session_id']));
    final second=request('group_encrypt',{
      'group_pickle':rotated['group_pickle'],
      'plaintext_b64':base64Encode(utf8.encode('New roster')),
    });
    expect(()=>request('group_decrypt',{
      'inbound_pickle':firstRead['inbound_pickle'],
      'message_b64':second['message_b64'],
    }),throwsException);
    final newInbound=request('group_import',{
      'session_key':rotated['session_key'],
    });
    final read=request('group_decrypt',{
      'inbound_pickle':newInbound['inbound_pickle'],
      'message_b64':second['message_b64'],
    });
    expect(utf8.decode(base64Decode(read['plaintext_b64'] as String)),
      'New roster');
  },skip:native==null);
}
