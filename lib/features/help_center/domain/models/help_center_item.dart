enum HelpCenterDestination { contactSupport, privacyHelp, safetyHelp, faq }

class HelpCenterItem {
  const HelpCenterItem({
    required this.id,
    required this.title,
    required this.keywords,
    required this.destination,
  });

  final String id;
  final String title;
  final List<String> keywords;
  final HelpCenterDestination destination;

  static const List<HelpCenterItem> demoItems = <HelpCenterItem>[
    HelpCenterItem(
      id: 'contact_support',
      title: 'Contact support',
      keywords: <String>['contact', 'support', 'help', 'phone', 'email'],
      destination: HelpCenterDestination.contactSupport,
    ),
    HelpCenterItem(
      id: 'privacy_help',
      title: 'Privacy help',
      keywords: <String>['privacy', 'location', 'data', 'visibility'],
      destination: HelpCenterDestination.privacyHelp,
    ),
    HelpCenterItem(
      id: 'safety_help',
      title: 'Safety help',
      keywords: <String>['safety', 'report', 'block', 'emergency', 'sos'],
      destination: HelpCenterDestination.safetyHelp,
    ),
    HelpCenterItem(
      id: 'faqs',
      title: 'FAQ’s',
      keywords: <String>['faq', 'faqs', 'questions', 'answers', 'common'],
      destination: HelpCenterDestination.faq,
    ),
  ];
}
