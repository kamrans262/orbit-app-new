import 'dart:typed_data';

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.fullName,
    required this.username,
    this.bio,
    this.profileImageReference,
    this.profilePhotoBytes,
  });

  final String fullName;
  final String username;
  final String? bio;

  /// Local path, upload token, or other backend-facing image reference.
  ///
  /// The UI keeps this nullable until the real upload pipeline is connected.
  final String? profileImageReference;
  /// Unsaved bytes stay only in memory until Save Changes is pressed.
  final Uint8List? profilePhotoBytes;
}

class EditProfileSaveException implements Exception {
  const EditProfileSaveException({
    this.fullNameError,
    this.usernameError,
    this.message,
  });

  final String? fullNameError;
  final String? usernameError;
  final String? message;
}
