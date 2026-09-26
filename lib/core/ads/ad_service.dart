/// Ad abstraction. Games and features never touch an ad SDK — they ask
/// this service for a reward. The first release ships with a fully local
/// mock implementation; swapping in a real SDK means implementing this
/// interface once, nothing else changes.
abstract class AdService {
  bool get isRewardedAdReady;

  /// Shows a rewarded ad. Returns true only when the reward was earned.
  ///
  /// Contract (enforced by convention and code review):
  ///   - never called during active puzzle solving,
  ///   - never called without an explicit user tap,
  ///   - never chained automatically.
  Future<bool> showRewardedAd();

  void preloadRewardedAd() {}
}
