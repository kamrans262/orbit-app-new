import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/data/orbit_identity_client.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';

class _NoContentIdentity extends OrbitIdentityClient {
  int views=0;
  bool deny=false;
  @override
  Future<Map<String,dynamic>> socialRequest(String method,String path,
      {Map<String,Object?>? body,String? idempotencyKey}) async{
    expect(method,'POST');
    expect(path,'/moments/test-moment/views');
    expect(body,{'context_id':'friends'});
    views++;
    if(deny)throw OrbitIdentityException('Unavailable',404);
    return <String,dynamic>{};
  }
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Moment view accepts Laravel 204 and still rejects authorization denial',()async{
    final identity=_NoContentIdentity();
    final repository=OrbitMomentRepository(identity:identity);
    final item=OrbitLiveMoment(id:'test-moment',creatorId:'owner',mediaId:'media',
      contextId:'friends',publishedAt:DateTime.now());
    await repository.view(item);
    expect(identity.views,1);
    identity.deny=true;
    await expectLater(repository.view(item),throwsA(isA<OrbitIdentityException>()));
  });
}
