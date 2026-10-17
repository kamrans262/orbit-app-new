class UpdatePopupData {
  const UpdatePopupData({
    required this.currentVersion,
    required this.newVersion,
    required this.title,
    required this.description,
    required this.changes,
    this.isForceUpdate = false,
    this.updateAction,
  });

  final String currentVersion;
  final String newVersion;
  final String title;
  final String description;
  final List<String> changes;
  final bool isForceUpdate;
  final Future<void> Function()? updateAction;

  static const UpdatePopupData demo = UpdatePopupData(
    currentVersion: 'v2.4.1',
    newVersion: 'v2.5.0',
    title: 'Update Available',
    description:
        'A new version of Orbit is available with new features and improvements.',
    changes: <String>[
      'Improved performance & stability',
      'New dashboard widgets',
      'Bug fixes and security updates',
    ],
  );
}

enum UpdatePopupResult { updateNow, later }
