/// Independent client-side M7 rollout gate. The Laravel flag and the user's
/// M3 privacy permissions remain additional, authoritative requirements.
/// M7 photo/video/voice features are ON by default for the consolidated app.
/// Backend grants, privacy checks and media gates remain authoritative.
/// Roll back locally with --dart-define=ORBIT_M7_MOMENTS_ENABLED=false.
abstract final class OrbitM7Rollout {
  static const bool enabled=bool.fromEnvironment(
    'ORBIT_M7_MOMENTS_ENABLED',defaultValue:true);
}
