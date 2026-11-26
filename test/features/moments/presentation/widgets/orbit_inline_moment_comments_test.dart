import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/data/orbit_moment_repository.dart';
import 'package:orbit_ui/features/moments/domain/models/moments_models.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/moment_image_card.dart';
import 'package:orbit_ui/features/moments/presentation/widgets/orbit_inline_moment_comments.dart';

class _Comments extends OrbitMomentRepository {
  bool allowed=true;
  int sent=0;
  final moment=OrbitLiveMoment(id:'post',creatorId:'author',mediaId:'media',contextId:'friends',
    publishedAt:DateTime.now(),likeCount:12,commentCount:1);
  @override
  Future<String?> currentUserId() async=>'reader';
  @override
  Future<OrbitLiveMoment> notificationMoment(String id,String context) async=>moment;
  @override
  Future<bool> remainsAuthorized(OrbitLiveMoment item) async=>allowed;
  @override
  Future<String> name(String userId) async=>'Friend';
  @override
  Future<List<({String id,String author,String body,String? parent})>> allComments(
      OrbitLiveMoment item,{int max=150}) async=>[
    (id:'first',author:'author',body:'Existing comment',parent:null),
  ];
  @override
  Future<String> commentWithReceipt(OrbitLiveMoment item,String text,{String? parent}) async{
    sent++;return 'confirmed';
  }
}

void main(){
  testWidgets('comments expand inside card, submit and update count without navigation',(tester)async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repo=_Comments();
    var expanded=false,count=1;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
      child:StatefulBuilder(builder:(context,update)=>MomentImageCard(
        data:MomentImageFeedItem(id:'post',author:const MomentAuthorData(id:'author',name:'Friend'),
          timeLabel:'Now',imagePath:null,title:'Moment',location:'',likeCount:12,commentCount:count),
        isLiked:false,isBookmarked:false,onLikePressed:(){},
        onCommentPressed:()=>update(()=>expanded=!expanded),onBookmarkPressed:(){},onSharePressed:(){},
        commentsContent:expanded?OrbitInlineMomentComments(moment:repo.moment,repository:repo,
          onClose:()=>update(()=>expanded=false),onCountChanged:(value)=>update(()=>count=value)):null,
      ))))));
    await tester.pumpAndSettle();
    expect(find.text('12'),findsOneWidget);
    expect(find.text('1'),findsOneWidget);
    final comment=find.byIcon(Icons.chat_bubble_outline_rounded);
    await tester.ensureVisible(comment);await tester.tap(comment);await tester.pumpAndSettle();
    expect(find.descendant(of:find.byType(MomentImageCard),matching:find.text('Existing comment')),findsOneWidget);
    final input=find.byType(TextField);
    await tester.ensureVisible(input);await tester.enterText(input,'New comment');
    final send=find.byIcon(Icons.send_rounded);
    await tester.ensureVisible(send);await tester.tap(send);await tester.pumpAndSettle();
    expect(repo.sent,1);expect(count,2);
    expect(find.descendant(of:find.byType(MomentImageCard),matching:find.text('New comment')),findsOneWidget);
    expect(find.byType(MomentImageCard),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
