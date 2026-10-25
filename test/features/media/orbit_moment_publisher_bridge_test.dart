import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/media/data/orbit_moment_media_stager.dart';
import 'package:orbit_ui/features/media/data/orbit_moment_publisher_bridge.dart';
import 'package:orbit_ui/features/moments/domain/models/moment_publish_models.dart';

void main() {
  test('Existing sheet publisher only succeeds after confirmed M7 commit', () async {
    var commits=0;
    final bridge=OrbitMomentPublisherBridge(
      stageEncryptedPhoto:(bytes,progress)async {
        progress(1);
        return const OrbitStagedPhoto(mediaId:'media-1',
          thumbnailVerified:true,privateGrantConfirmed:true);
      },
      commitActualMoment:({required mediaId,required circleIds,
        required caption})async {
        commits++;
        expect(mediaId,'media-1');
        expect(circleIds,{'circle-1'});
        return const OrbitConfirmedMoment(momentId:'moment-1',
          audienceKeysConfirmed:true);
      },
    );
    final progress=<double>[];
    final receipt=await bridge.publisher(MomentPublishRequest(
      photoBytes:Uint8List.fromList([1,2]),
      circleIds:{'circle-1'},caption:'Hello'),progress.add);
    expect(receipt.momentId,'moment-1');
    expect(commits,1);
    expect(progress.last,1);
  });

  test('No false publishing when recipient keys are not confirmed', () async {
    final bridge=OrbitMomentPublisherBridge(
      stageEncryptedPhoto:(bytes,progress)async =>
        const OrbitStagedPhoto(mediaId:'media-1',
          thumbnailVerified:true,privateGrantConfirmed:true),
      commitActualMoment:({required mediaId,required circleIds,
        required caption})async =>
        const OrbitConfirmedMoment(momentId:'moment-1',
          audienceKeysConfirmed:false),
    );
    await expectLater(bridge.publisher(MomentPublishRequest(
      photoBytes:Uint8List.fromList([2]),
      circleIds:{'circle-1'},caption:''),(value){}),throwsStateError);
  });
}
