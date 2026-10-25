# Orbit Home Debug Seed Preview

This is **local UI fixture data**, not database seeds. Laravel does not yet
offer a Plans CRUD table or endpoint, so inserting real-looking plans into
production tables would be misleading and could expose fake people to users.

In a local Flutter debug build, the Home preview is enabled automatically.
It supplies three visibly labeled demo Next Up plans, example participant
avatars, example friend avatars, Recent Moments thumbnails and a sample promo.
All images are existing checked-in assets. Live authorized profiles and Moments
are preserved and take precedence. Tapping any demo plan/person/Moment only
shows a notice; it never performs authenticated or server-side actions.

- Debug default: `flutter run`
- Disable fixtures: `flutter run --dart-define=ORBIT_DEMO_HOME=false`
- Explicitly enable fixtures: `flutter run --dart-define=ORBIT_DEMO_HOME=true`

Release/profile modes never include this preview, even when the flag is set.
No backend migrations, production records or media-permission policies change.
