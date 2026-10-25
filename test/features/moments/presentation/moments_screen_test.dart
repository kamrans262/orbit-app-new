import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/moments/domain/models/moments_models.dart';
import 'package:orbit_ui/features/moments/presentation/screens/moments_screen.dart';
import 'package:orbit_ui/core/widgets/app_emoji_safe_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget wrap(Widget child) => MaterialApp(home: child);

  for (final size in <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
    const Size(600, 960),
  ]) {
    testWidgets('Moments stays overflow-safe at ${size.width}x${size.height}', (
      tester,
    ) async {
      await setPhoneSize(tester, size);
      await tester.pumpWidget(wrap(MomentsScreen.demo()));
      await tester.pumpAndSettle();

      expect(find.text('Moments'), findsWidgets);
      expect(find.byKey(MomentsKeys.storiesList), findsOneWidget);
      // The feed is a lazy SliverList: short viewports do not build its cards
      // until scrolled into view. Emoji are rendered as icon spans, not text.
      final feedScroll = find.descendant(
        of: find.byKey(MomentsKeys.feed),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        find.byKey(MomentsKeys.feedItem('sunset-walk')),
        180,
        scrollable: feedScroll,
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppEmojiSafeText &&
              widget.data == 'Sunset walk \u{1F305}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(MomentsKeys.feedItem('mike-run')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Just finished a 10k run!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('demo image Moment uses the supplied moment_card JPG', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    await tester.pumpWidget(wrap(MomentsScreen.demo()));
    await tester.pumpAndSettle();

    final assetImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>();

    expect(
      assetImages.any((image) => image.assetName == 'assets/moment_card.jpg'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Moments center plus opens camera and hides bottom navigation', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      wrap(
        MomentsScreen.demo(
          cameraBuilder: (_) =>
              const Scaffold(body: Center(child: Text('Camera route test'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Allow Camera Access'), findsOneWidget);
    await tester.tap(find.byKey(const Key('orbit_popup_primary_cameraPermission')));
    await tester.pumpAndSettle();

    expect(find.text('Camera route test'), findsOneWidget);
    expect(find.byKey(MomentsKeys.bottomNavigation), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'like and bookmark states toggle and report backend-ready values',
    (tester) async {
      await setPhoneSize(tester, const Size(390, 844));
      bool? liked;
      bool? bookmarked;
      const item = MomentImageFeedItem(
        id: 'image',
        author: MomentAuthorData(id: 'a', name: 'A Very Long Author Name'),
        timeLabel: 'Now',
        imagePath: 'assets/does_not_exist.jpg',
        title: 'A responsive image post',
        location: 'A very long backend location that must stay safe',
        likeCount: 9,
        commentCount: 2,
      );

      await tester.pumpWidget(
        wrap(
          _screen(
            feedItems: const <MomentFeedItem>[item],
            onLikeChanged: (post, value) => liked = value,
            onBookmarkChanged: (post, value) => bookmarked = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final post = find.byKey(MomentsKeys.feedItem('image'));
      await tester.scrollUntilVisible(
        post,
        200,
        scrollable: find.descendant(
          of: find.byKey(MomentsKeys.feed),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.pumpAndSettle();
      // Semantics *nodes* below the image are culled outside the viewport,
      // while the Semantics widget remains in the mounted image card.
      // Locate the real accessible action widget, then bring it into view.
      Finder action(String label) => find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      );
      final like = action('Like moment');
      expect(like, findsOneWidget);
      await tester.ensureVisible(like);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(like, findsOneWidget);
      await tester.tap(like);
      await tester.pump();
      expect(liked, isTrue);
      expect(action('Unlike moment'), findsOneWidget);

      final bookmark = action('Bookmark moment');
      expect(bookmark, findsOneWidget);
      await tester.ensureVisible(bookmark);
      await tester.pumpAndSettle();
      await tester.tap(bookmark);
      await tester.pump();
      expect(bookmarked, isTrue);
      expect(action('Remove bookmark'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('M7 offline private previews never optimistically like or save',
      (tester) async {
    await setPhoneSize(tester,const Size(390,844));
    const item=MomentImageFeedItem(
      id:'cached-preview',
      author:MomentAuthorData(id:'owner',name:'Orbit member'),
      timeLabel:'Offline',title:'',location:'',
      imagePath:'assets/does_not_exist.jpg',
      likeCount:0,commentCount:0,
    );
    var likes=0,saves=0;
    await tester.pumpWidget(wrap(MomentsScreen(
      privateMode:true,privateReadOnly:true,privateBookmarking:true,
      stories:const [],feedItems:const <MomentFeedItem>[item],
      viewState:MomentsViewState.populated,
      onSearchPressed:(){},onFilterPressed:(){},onMessagesPressed:(){},
      onStoryPressed:(_){},onLikeChanged:(_,__)=>likes++,
      onCommentPressed:(_){},onBookmarkChanged:(_,__)=>saves++,
      onSharePressed:(_){},onTextMenuPressed:(_){},
      onFeedItemPressed:(_){},onTabSelected:(_){},onAddPressed:(){},
    )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(MomentsKeys.feedItem('cached-preview')),200,
      scrollable:find.descendant(
        of:find.byKey(MomentsKeys.feed),
        matching:find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    Finder action(String label)=>find.byWidgetPredicate(
      (w)=>w is Semantics && w.properties.label==label);
    final like=action('Like moment');
    await tester.ensureVisible(like);
    await tester.tap(like);
    await tester.pump();
    expect(likes,0);
    expect(action('Unlike moment'),findsNothing);
    final bookmark=action('Bookmark moment');
    await tester.ensureVisible(bookmark);
    await tester.tap(bookmark);
    await tester.pump();
    expect(saves,0);
    expect(action('Remove bookmark'),findsNothing);
  });

  testWidgets('dynamic feed accepts mixed order and future video items', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));
    const author = MomentAuthorData(
      id: 'backend-user',
      name: 'Backend User With A Very Long Name That Must Never Overflow',
      imagePath: 'assets/missing_profile.png',
    );
    final feed = <MomentFeedItem>[
      const MomentTextFeedItem(
        id: 'text-first',
        author: author,
        timeLabel: '15m ago',
        text: 'This is a very long backend caption that should wrap naturally across as many lines as required without any fixed card height or vertical overflow. It can continue with more text and still remain readable on a compact phone.',
      ),
      const MomentFutureVideoFeedItem(
        id: 'video-second',
        author: author,
        timeLabel: '20m ago',
        caption: 'Future video item placeholder',
        thumbnailPath: 'assets/missing_video_thumbnail.jpg',
      ),
      const MomentPromoFeedItem(
        id: 'promo-third',
        backgroundImagePath: 'assets/missing_banner.png',
        logoImagePath: 'assets/missing_logo.png',
        title: 'Get there together',
        subtitle: 'Ride with friends',
      ),
    ];

    await tester.pumpWidget(wrap(_screen(feedItems: feed)));
    await tester.pumpAndSettle();
    expect(find.byKey(MomentsKeys.feedItem('text-first')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(MomentsKeys.feedItem('promo-third')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(MomentsKeys.feedItem('video-second')), findsOneWidget);
    expect(find.byKey(MomentsKeys.feedItem('promo-third')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading empty and error states are safe', (tester) async {
    await setPhoneSize(tester, const Size(390, 844));

    await tester.pumpWidget(wrap(_screen(viewState: MomentsViewState.loading)));
    await tester.pump();
    expect(find.byKey(MomentsKeys.loadingState), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(_screen(viewState: MomentsViewState.empty)));
    await tester.pump();
    expect(find.byKey(MomentsKeys.emptyState), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      wrap(
        _screen(
          viewState: MomentsViewState.error,
          errorMessage: 'A long backend error message can wrap safely instead of overflowing the state card.',
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(MomentsKeys.errorState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many backend records and missing images remain scroll-safe', (
    tester,
  ) async {
    await setPhoneSize(tester, const Size(320, 568));
    final stories = List<MomentStoryData>.generate(
      30,
      (index) => MomentStoryData(
        id: 'story-$index',
        name: 'Long Story Name $index',
        imagePath: 'assets/missing_story_$index.png',
      ),
    );
    final feed = List<MomentFeedItem>.generate(
      40,
      (index) => MomentTextFeedItem(
        id: 'text-$index',
        author: MomentAuthorData(
          id: 'author-$index',
          name: 'Very Long Backend Person Name Number $index',
          imagePath: 'assets/missing_author_$index.png',
        ),
        timeLabel: 'A long time label from backend $index',
        text:
            'Backend content item $index can contain long wrapping text. The card must grow naturally and must never use a fixed content height.',
      ),
    );

    await tester.pumpWidget(wrap(_screen(stories: stories, feedItems: feed)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(MomentsKeys.feedItem('text-39')),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(MomentsKeys.feedItem('text-39')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

MomentsScreen _screen({
  List<MomentStoryData> stories = const <MomentStoryData>[],
  List<MomentFeedItem> feedItems = const <MomentFeedItem>[],
  MomentsViewState viewState = MomentsViewState.populated,
  String errorMessage = 'Error',
  void Function(MomentImageFeedItem item, bool isLiked)? onLikeChanged,
  void Function(MomentImageFeedItem item, bool isBookmarked)? onBookmarkChanged,
}) {
  return MomentsScreen(
    stories: stories,
    feedItems: feedItems,
    viewState: viewState,
    errorMessage: errorMessage,
    onSearchPressed: () {},
    onFilterPressed: () {},
    onMessagesPressed: () {},
    onStoryPressed: (story) {},
    onLikeChanged: onLikeChanged ?? (item, value) {},
    onCommentPressed: (item) {},
    onBookmarkChanged: onBookmarkChanged ?? (item, value) {},
    onSharePressed: (item) {},
    onTextMenuPressed: (item) {},
    onFeedItemPressed: (item) {},
    onTabSelected: (index) {},
    onAddPressed: () {},
  );
}
