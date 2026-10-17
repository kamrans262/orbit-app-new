/// Shared OTP layout metrics derived from the existing Reset Password card.
///
/// The 36px OTP-to-action gap keeps the Verify button at the same vertical
/// position as the Reset Password "Send Reset Link" button on the reference
/// auth layout, without using a large arbitrary spacer.
abstract final class AuthOtpLayoutMetrics {
  static const double subtitleToOtpGap = 20;
  static const double otpToActionGap = 36;
}
