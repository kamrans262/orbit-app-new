import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_api.dart';
import 'package:orbit_ui/features/messaging/data/orbit_messaging_models.dart';

class _SenderKeyApi extends OrbitMessagingApi {
  String? lastMethod,lastPath;
  Map<String,Object?>? lastBody;

  @override
  Future<Map<String,dynamic>> request(String method,String path,{
      Map<String,Object?>? body}) async {
    lastMethod=method;lastPath=path;lastBody=body;
    if(method=='POST'){
      return {'id':'batch','group_epoch':9,'stored':true,
        'recipient_delivered':false,'ciphertext_only':true};
    }
    return {'group_epoch':9,'next_cursor':null,'items':[{
      'id':'envelope','sender_id':'sender',
      'sender_device_id':'sender-device',
      'recipient_key_version':4,'protocol':'reviewed.test',
      'group_epoch':9,'ciphertext_b64':'opaque-base64',
      'protocol_header_b64':'opaque-header',
    }]};
  }
}

void main(){
  test('Read-only Circle sender-key mailbox has device ciphertext only',() async {
    final api=_SenderKeyApi();
    final page=await api.circleSenderKeys('circle-thread',limit:30);
    expect(api.lastMethod,'GET');
    expect(api.lastPath,contains('/conversations/circle-thread/sender-keys'));
    expect(page.groupEpoch,9);
    expect(page.items,singleElement);
    expect(page.items.single.senderDeviceId,'sender-device');
    expect(page.items.single.ciphertextB64,'opaque-base64');
  });

  test('Sender-key publication sends per-device encrypted envelopes only',() async {
    final api=_SenderKeyApi();
    final result=await api.distributeCircleSenderKey('thread',
      clientId:'client-id',groupEpoch:9,protocol:'reviewed.test',
      envelopes:const [
        OrbitCipherEnvelope(deviceId:'device',ciphertextB64:'sealed',
          headerB64:'signed-header'),
      ],
    );
    expect(result.stored,isTrue);
    expect(result.groupEpoch,9);
    expect(api.lastMethod,'POST');
    expect(api.lastPath,'/conversations/thread/sender-keys');
    expect(api.lastBody!.keys,
      containsAll(['client_id','protocol','group_epoch','envelopes']));
    expect(api.lastBody!.containsKey('sender_key'),isFalse);
    expect(api.lastBody!.containsKey('plaintext'),isFalse);
    final envelopes=api.lastBody!['envelopes'] as List;
    expect((envelopes.first as Map).keys,
      containsAll(['device_id','ciphertext_b64','protocol_header_b64']));
  });
}
