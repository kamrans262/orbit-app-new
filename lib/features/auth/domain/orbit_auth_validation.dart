/// Client-side feedback only; Laravel repeats all authentication checks.
abstract final class OrbitAuthValidation {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^\+[1-9]\d{7,14}$');
  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'[0-9]');

  static String? recipient(String value) {
    final v = value.trim();
    if (v.length > 190 || !(_email.hasMatch(v) || _phone.hasMatch(v))) {
      return 'Enter a valid email or international phone number (+country code).';
    }
    return null;
  }

  static String? password(String value, {bool newPassword = true}) {
    if (value.isEmpty) return 'Enter your password.';
    if (value.length > 256) return 'Password cannot exceed 256 characters.';
    if (newPassword &&
        (value.length < 10 || !_letter.hasMatch(value) || !_digit.hasMatch(value))) {
      return 'Use at least 10 characters, including a letter and a number.';
    }
    return null;
  }

  static String? signup(String name, String destination, String secret) {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 120) {
      return 'Full name must be between 2 and 120 characters.';
    }
    return recipient(destination) ?? password(secret);
  }

  static String? login(String destination, String secret) =>
      recipient(destination) ?? password(secret, newPassword: false);
}
