import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/domain/models/moments_models.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moments_screen.dart';

void main() {
  testWidgets('M18 Check-In reuses approved Moments text card with existing source action',
      (tester) async {
    var opened=0,reported=0;
    const checkIn=MomentTextFeedItem(
      id:'activity-check-in:a0000000-0000-4000-8000-000000000001',
      author:MomentAuthorData(id:'source-owner',name:'Friend'),
      timeLabel:'5m ago',
      text:'Check-In · Coffee',
      isCheckIn:true,
    );
    await tester.pumpWidget(MaterialApp(home:MomentsScreen(
      privateMode:true,
      stories:const [],
      feedItems:const [checkIn],
      onSearchPressed:(){},onFilterPressed:(){},
      onMessagesPressed:(){},onStoryPressed:(_){},
      onLikeChanged:(_,__){},onCommentPressed:(_){},
      onBookmarkChanged:(_,__){},onSharePressed:(_){},
      onTextMenuPressed:(_){reported++;},
      onFeedItemPressed:(_){opened++;},
      onTabSelected:(_){},onAddPressed:(){},
    )));
    await tester.pump();
    expect(find.text('Check-In · Coffee'),findsOneWidget);
    final detail=find.byTooltip('View Check-In');
    await tester.ensureVisible(detail);
    await tester.tap(detail);
    await tester.pump();
    expect(opened,1);
    expect(reported,0);
    expect(find.text('Report User'),findsNothing);
    expect(find.text('Moments'),findsWidgets);
  });

  testWidgets('Unchanged regular Moment text card keeps its approved menu',
      (tester) async {
    const moment=MomentTextFeedItem(
      id:'text-moment',
      author:MomentAuthorData(id:'author',name:'Friend'),
      timeLabel:'2m ago',
      text:'Normal Moment',
    );
    await tester.pumpWidget(MaterialApp(home:MomentsScreen(
      privateMode:true,
      stories:const [],
      feedItems:const [moment],
      onSearchPressed:(){},onFilterPressed:(){},
      onMessagesPressed:(){},onStoryPressed:(_){},
      onLikeChanged:(_,__){},onCommentPressed:(_){},
      onBookmarkChanged:(_,__){},onSharePressed:(_){},
      onTextMenuPressed:(_){},
      onFeedItemPressed:(_){},
      onTabSelected:(_){},onAddPressed:(){},
    )));
    expect(find.byTooltip('Moment options'),findsOneWidget);
    expect(find.byTooltip('View Check-In'),findsNothing);
  });
}
