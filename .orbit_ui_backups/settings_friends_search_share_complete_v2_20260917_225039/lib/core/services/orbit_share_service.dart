import 'package:share_plus/share_plus.dart';

abstract final class OrbitShareService {
  static Future<void> shareText(String text, {String? subject}) {
    return Share.share(text, subject: subject);
  }

  static Future<void> shareOrbit() {
    return shareText('Join me on Orbit.', subject: 'Orbit');
  }

  static Future<void> shareProfile({
    required String displayName,
    String? profileLink,
  }) {
    final link = profileLink?.trim();
    final suffix = link == null || link.isEmpty ? '' : '\n$link';
    return shareText(
      'Check out $displayName on Orbit.$suffix',
      subject: '$displayName on Orbit',
    );
  }

  static Future<void> shareMoment({
    String? authorName,
    String? text,
    String? location,
  }) {
    final parts = <String>[
      if (authorName != null && authorName.trim().isNotEmpty)
        '${authorName.trim()} shared a moment on Orbit.',
      if (text != null && text.trim().isNotEmpty) text.trim(),
      if (location != null && location.trim().isNotEmpty)
        'Location: ${location.trim()}',
    ];

    return shareText(
      parts.isEmpty ? 'Check out this moment on Orbit.' : parts.join('\n'),
      subject: 'Orbit Moment',
    );
  }

  static Future<void> shareLocation({required String locationText}) {
    return shareText(
      'My location on Orbit: ${locationText.trim()}',
      subject: 'Orbit Location',
    );
  }
}
