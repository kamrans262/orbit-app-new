import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/orbit_searchable_header.dart';
import '../../domain/models/nearby_person.dart';
import '../widgets/invite_option_tile.dart';
import '../widgets/nearby_person_tile.dart';
import '../widgets/welcome_action_panel.dart';

abstract final class InvitePeopleKeys {
  static const heading = Key('invite_people_heading');
  static const loginShortcut = Key('invite_people_login_shortcut');
  static const body = Key('invite_people_body');
  static const nearbyHeading = Key('invite_people_nearby_heading');
  static const nearbyList = Key('invite_people_nearby_list');
  static const doneButton = Key('invite_people_done_button');
  static const skipButton = Key('invite_people_skip_button');
  static const searchField = Key('invite_people_search_field');

  static Key option(int index) => Key('invite_people_option_$index');
  static Key person(int index) => Key('invite_people_person_$index');
  static Key image(int index) => Key('invite_people_image_$index');
  static Key add(int index) => Key('invite_people_add_$index');
}

class InvitePeopleScreen extends StatelessWidget {
  const InvitePeopleScreen({
    required this.onInviteByContacts,
    required this.onInviteByQrCode,
    required this.onInviteByLink,
    required this.onInviteByUsername,
    required this.onAddPerson,
    required this.onOpenLogin,
    this.onDone,
    this.onSkip,
    this.nearbyPeople = NearbyPerson.demoPeople,
    this.isCircleInvite = false,
    this.onBack,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
    this.peopleHeading = 'Near By People',
    this.loadingPeople = false,
    this.peopleError,
    this.onRetryPeople,
    this.canAddPerson = true,
    this.emptyPeopleMessage,
    super.key,
  });

  static const double _screenHorizontalPadding = 20;
  static const double _headingToBodyGap = 10;
  static const double _bodyToOptionsGap = 20;
  static const double _optionGap = 10;
  static const double _optionsToNearbyGap = 20;
  static const double _nearbyHeadingToListGap = 8;

  final VoidCallback onInviteByContacts;
  final VoidCallback onInviteByQrCode;
  final VoidCallback onInviteByLink;
  final VoidCallback onInviteByUsername;
  final ValueChanged<NearbyPerson> onAddPerson;
  final VoidCallback onOpenLogin;
  final VoidCallback? onDone;
  final VoidCallback? onSkip;
  final List<NearbyPerson> nearbyPeople;
  /// Reuse this original screen for authenticated Circle invitations. The
  /// onboarding header and demo data remain unchanged for existing callers.
  final bool isCircleInvite;
  final VoidCallback? onBack;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;
  final String peopleHeading;
  final bool loadingPeople;
  final String? peopleError;
  final VoidCallback? onRetryPeople;
  final bool canAddPerson;
  final String? emptyPeopleMessage;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.sizeOf(context).height < 720 ? 12.0 : 52.0;
    // Production must never show the onboarding's demo nearby people.
    final visiblePeople = isCircleInvite
        ? nearbyPeople.where((person) => person.id?.isNotEmpty == true)
            .toList(growable: false)
        : nearbyPeople;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            _screenHorizontalPadding,
            topPadding,
            _screenHorizontalPadding,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isCircleInvite) ...<Widget>[
                    AppScreenHeader(
                      title: 'Add People',
                      prominent: true,
                      onBack: onBack,
                      titleKey: InvitePeopleKeys.heading,
                    ),
                    const SizedBox(height: 20),
                    KeyedSubtree(
                      key: InvitePeopleKeys.searchField,
                      child: searchController != null && searchFocusNode != null
                          ? OrbitSearchField(
                              controller: searchController!,
                              focusNode: searchFocusNode!,
                              placeholder: 'Search by name or username',
                              autofocus: false,
                              onChanged: onSearchChanged ?? (_) {},
                            )
                          : AppTextField(
                              hintText: 'Search by name or username',
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: Color(0xFF94A3B8)),
                              onChanged: onSearchChanged,
                            ),
                    ),
                    const SizedBox(height: _bodyToOptionsGap),
                  ] else ...<Widget>[
                    Semantics(
                      button: true,
                      label: 'Open login',
                      child: GestureDetector(
                        key: InvitePeopleKeys.loginShortcut,
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpenLogin,
                        child: const Text(
                          'Invite People',
                          key: InvitePeopleKeys.heading,
                          textAlign: TextAlign.center,
                          style: AppTypography.largeHeading,
                        ),
                      ),
                    ),
                    const SizedBox(height: _headingToBodyGap),
                    Text(
                      'Add People To Your Circle',
                      key: InvitePeopleKeys.body,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: _bodyToOptionsGap),
                  ],
                  InviteOptionTile(
                    containerKey: InvitePeopleKeys.option(0),
                    icon: Icons.people_alt_outlined,
                    label: 'Invite by Contacts',
                    onTap: onInviteByContacts,
                  ),
                  const SizedBox(height: _optionGap),
                  InviteOptionTile(
                    containerKey: InvitePeopleKeys.option(1),
                    icon: Icons.qr_code_2_rounded,
                    label: 'Invite by QR Code',
                    onTap: onInviteByQrCode,
                  ),
                  const SizedBox(height: _optionGap),
                  InviteOptionTile(
                    containerKey: InvitePeopleKeys.option(2),
                    icon: Icons.link_rounded,
                    label: 'Invite by Link',
                    onTap: onInviteByLink,
                  ),
                  const SizedBox(height: _optionGap),
                  InviteOptionTile(
                    containerKey: InvitePeopleKeys.option(3),
                    icon: Icons.alternate_email_rounded,
                    label: 'Invite by Username',
                    onTap: onInviteByUsername,
                  ),
                  if (isCircleInvite &&
                      (loadingPeople || peopleError != null ||
                          visiblePeople.isEmpty)) ...<Widget>[
                    const SizedBox(height: _optionsToNearbyGap),
                    if (loadingPeople)
                      const Center(child: CircularProgressIndicator(
                          color: AppColors.primaryEnd))
                    else if (peopleError != null)
                      Column(children: <Widget>[
                        Text(peopleError!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: onRetryPeople,
                          child: const Text('Try again'),
                        ),
                      ])
                    else
                      Text(
                        emptyPeopleMessage ??
                        'No eligible friends to invite. Existing members and '
                        'pending invitations are excluded.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                  if (visiblePeople.isNotEmpty) ...[
                  const SizedBox(height: _optionsToNearbyGap),
                  Text(
                    peopleHeading,
                    key: InvitePeopleKeys.nearbyHeading,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: <String>[
                        'Noto Color Emoji',
                        'Apple Color Emoji',
                        'Segoe UI Emoji',
                      ],
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F1724),
                    ),
                  ),
                  const SizedBox(height: _nearbyHeadingToListGap),
                  ListView.separated(
                    key: InvitePeopleKeys.nearbyList,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: visiblePeople.length,
                    itemBuilder: (context, index) {
                      final person = visiblePeople[index];
                      return NearbyPersonTile(
                        tileKey: InvitePeopleKeys.person(index),
                        imageKey: InvitePeopleKeys.image(index),
                        addButtonKey: InvitePeopleKeys.add(index),
                        person: person,
                        enabled: canAddPerson,
                        onAdd: () => onAddPerson(person),
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const Padding(
                        padding: EdgeInsets.only(left: 60),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFD8D8D8),
                        ),
                      );
                    },
                  ),
                  ],
                  if (onDone != null && onSkip != null) ...<Widget>[
                    const SizedBox(height: 24),
                    // Reuse the same primary/secondary actions as onboarding.
                    // Done completes the step; it does not fabricate an invite.
                    WelcomeActionPanel(
                      primaryKey: InvitePeopleKeys.doneButton,
                      primaryLabel: 'Done',
                      onPrimaryPressed: onDone!,
                      secondaryKey: InvitePeopleKeys.skipButton,
                      secondaryLabel: 'Skip',
                      onSecondaryPressed: onSkip,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
