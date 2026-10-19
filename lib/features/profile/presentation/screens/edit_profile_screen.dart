import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_screen_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/edit_profile_models.dart';
import '../../domain/models/profile_models.dart';
import '../widgets/profile_media_image.dart';

abstract final class EditProfileKeys {
  static const scrollView = Key('edit_profile_scroll_view');
  static const backButton = Key('edit_profile_back_button');
  static const title = Key('edit_profile_title');
  static const avatar = Key('edit_profile_avatar');
  static const changePhoto = Key('edit_profile_change_photo');
  static const fullNameField = Key('edit_profile_full_name_field');
  static const usernameField = Key('edit_profile_username_field');
  static const saveButton = Key('edit_profile_save_button');
  static const takePhoto = Key('edit_profile_take_photo');
  static const chooseGallery = Key('edit_profile_choose_gallery');
}

enum EditProfilePhotoSource { camera, gallery }

class EditProfilePhotoSelection {
  const EditProfilePhotoSelection({
    required this.previewImage,
    this.profileImageReference,
  });

  final ImageProvider<Object> previewImage;
  final String? profileImageReference;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.profile,
    this.initialFullName,
    this.initialUsername,
    this.onBack,
    this.onPickPhoto,
    this.onSave,
    super.key,
  });

  final ProfileData profile;
  final String? initialFullName;
  final String? initialUsername;
  final VoidCallback? onBack;
  final Future<EditProfilePhotoSelection?> Function(
    EditProfilePhotoSource source,
  )?
  onPickPhoto;
  final Future<void> Function(UpdateProfileRequest request)? onSave;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _background = Color(0xFFF9F9F9);
  static const double _horizontalPadding = 20;
  static const double _topPadding = 20;
  static const double _headerToBodyGap = 20;
  static const double _avatarSize = 80;
  static const double _avatarToChangePhotoGap = 8;
  static const double _changePhotoToFieldsGap = 16;
  static const double _fieldGap = 18;
  static const double _buttonBottomGap = 50;
  static const double _maxContentWidth = 430;

  static const LinearGradient _orbitGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[Color(0xFFC857D6), Color(0xFF7C5CFC)],
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;

  EditProfilePhotoSelection? _selectedPhoto;
  bool _isSaving = false;
  String? _serverFullNameError;
  String? _serverUsernameError;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: _initialFullName());
    _usernameController = TextEditingController(text: _initialUsername());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _initialFullName() {
    final explicit = widget.initialFullName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    // Preserve the supplied Figma/demo data while real profiles continue to
    // use backend values. The existing Orbit demo profile has id "emma".
    if (widget.profile.id == 'emma') {
      return 'Emma Shan';
    }

    final cleaned = widget.profile.name
        .replaceAll(RegExp(r'\s*[â­â˜…]\s*$'), '')
        .trim();
    return cleaned.isEmpty ? 'Emma Shan' : cleaned;
  }

  String _initialUsername() {
    final explicit = widget.initialUsername?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final rawName = _initialFullName();
    final firstToken = rawName.split(RegExp(r'\s+')).first;
    final sanitized = firstToken.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
    return sanitized.isEmpty ? 'Emma' : sanitized;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _horizontalPadding,
                      _topPadding,
                      _horizontalPadding,
                      0,
                    ),
                    child: AppScreenHeader(
                      title: 'Edit Profile',
                      backButtonKey: EditProfileKeys.backButton,
                      titleKey: EditProfileKeys.title,
                      onBack: widget.onBack,
                    ),
                  ),
                  const SizedBox(height: _headerToBodyGap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            key: EditProfileKeys.scrollView,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: _horizontalPadding,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _ProfileAvatar(
                                      key: EditProfileKeys.avatar,
                                      profile: widget.profile,
                                      selectedPhoto: _selectedPhoto,
                                      size: _avatarSize,
                                    ),
                                    const SizedBox(
                                      height: _avatarToChangePhotoGap,
                                    ),
                                    Center(
                                      child: _GradientTextAction(
                                        key: EditProfileKeys.changePhoto,
                                        label: 'Change Photo',
                                        gradient: _orbitGradient,
                                        onTap: _showPhotoSourceSheet,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: _changePhotoToFieldsGap,
                                    ),
                                    AppTextField(
                                      label: 'Full Name',
                                      fieldKey: EditProfileKeys.fullNameField,
                                      controller: _fullNameController,
                                      textInputAction: TextInputAction.next,
                                      validator: _validateFullName,
                                      onChanged: (_) {
                                        if (_serverFullNameError != null) {
                                          setState(
                                            () => _serverFullNameError = null,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: _fieldGap),
                                    AppTextField(
                                      label: 'User Name',
                                      fieldKey: EditProfileKeys.usernameField,
                                      controller: _usernameController,
                                      textInputAction: TextInputAction.done,
                                      validator: _validateUsername,
                                      onChanged: (_) {
                                        if (_serverUsernameError != null) {
                                          setState(
                                            () => _serverUsernameError = null,
                                          );
                                        }
                                      },
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 24),
                                    IgnorePointer(
                                      ignoring: _isSaving,
                                      child: KeyedSubtree(
                                        key: EditProfileKeys.saveButton,
                                        child: AppPrimaryButton(
                                          label: _isSaving
                                              ? 'Saving Changes...'
                                              : 'Save Changes',
                                          onPressed: _handleSave,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: _buttonBottomGap),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateFullName(String? value) {
    if (_serverFullNameError != null) {
      return _serverFullNameError;
    }

    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter your full name';
    }
    if (trimmed.length < 2) {
      return 'Use at least 2 characters';
    }
    if (trimmed.length > 120) {
      return 'Keep the name under 120 characters';
    }
    if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-ž' .-]+$").hasMatch(trimmed)) {
      return 'Use letters, spaces, apostrophes, dots, or hyphens';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (_serverUsernameError != null) {
      return _serverUsernameError;
    }

    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter a username';
    }
    if (trimmed.length < 3) {
      return 'Use at least 3 characters';
    }
    if (trimmed.length > 32) {
      return 'Keep the username under 32 characters';
    }
    if (!RegExp(r'^[A-Za-z0-9._]+$').hasMatch(trimmed)) {
      return 'Use only letters, numbers, dots, or underscores';
    }
    return null;
  }

  Future<void> _showPhotoSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final source = await showModalBottomSheet<EditProfilePhotoSource>(
      context: context,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Change Photo',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F1724),
                ),
              ),
              const SizedBox(height: 12),
              _PhotoSourceAction(
                key: EditProfileKeys.takePhoto,
                icon: Icons.photo_camera_outlined,
                label: 'Take Photo',
                onTap: () =>
                    Navigator.of(sheetContext)
                        .pop(EditProfilePhotoSource.camera),
              ),
              const SizedBox(height: 8),
              _PhotoSourceAction(
                key: EditProfileKeys.chooseGallery,
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () =>
                    Navigator.of(sheetContext)
                        .pop(EditProfilePhotoSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    final picker = widget.onPickPhoto;
    if (picker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == EditProfilePhotoSource.camera
                ? 'Camera picker is ready to connect.'
                : 'Gallery picker is ready to connect.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selection = await picker(source);
    if (selection == null || !mounted) {
      return;
    }

    setState(() => _selectedPhoto = selection);
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _serverFullNameError = null;
      _serverUsernameError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final request = UpdateProfileRequest(
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      profileImageReference: _selectedPhoto?.profileImageReference,
    );

    setState(() => _isSaving = true);
    try {
      final save = widget.onSave;
      if (save != null) {
        await save(request);
      } else {
        // UI-only demo persistence. Replace with the profile update API later.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile changes saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on EditProfileSaveException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serverFullNameError = error.fullNameError;
        _serverUsernameError = error.usernameError;
      });
      _formKey.currentState?.validate();

      if (error.message != null && error.message!.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.selectedPhoto,
    required this.size,
    super.key,
  });

  final ProfileData profile;
  final EditProfilePhotoSelection? selectedPhoto;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: selectedPhoto == null
              ? ProfileMediaImage(
                  assetPath: profile.imagePath,
                  imageUrl: profile.imageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fallbackAspectRatio: 1,
                )
              : Image(
                  image: selectedPhoto!.previewImage,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                      child: Center(
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 30,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _GradientTextAction extends StatelessWidget {
  const _GradientTextAction({
    required this.label,
    required this.gradient,
    required this.onTap,
    super.key,
  });

  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: gradient.createShader,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceAction extends StatelessWidget {
  const _PhotoSourceAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: const Color(0xFF7C5CFC)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
