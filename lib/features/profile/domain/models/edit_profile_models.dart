class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.fullName,
    required this.username,
    this.bio,
    this.profileImageReference,
  });

  final String fullName;
  final String username;
  final String? bio;

  /// Local path, upload token, or other backend-facing image reference.
  ///
  /// The UI keeps this nullable until the real upload pipeline is connected.
  final String? profileImageReference;
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
