import '../ads/ad_service.dart';
import '../storage/local_storage.dart';
import 'progress_service.dart';

/// Coordinates the hint economy: gating, persistence, and the ad exchange.
///
/// The flow is always user-initiated:
///   tap Hint → confirmation sheet → (optional) rewarded ad → board reveal.
/// This service never triggers anything automatically.
class HintService {
  HintService(this._storage, this._progress, this._ads);

  final LocalStorage _storage;
  final ProgressService _progress;
  final AdService _ads;

  /// Soft cap per level so hints can't become a solution machine.
  static const int maxHintsPerLevel = 3;

  String _key(String gameId, int level) =>
      '${StorageKeys.hintsPrefix}$gameId.$level';

  int hintsUsedFor(String gameId, int level) =>
      _storage.getInt(_key(gameId, level));

  bool canShowHint(String gameId, int level) =>
      hintsUsedFor(gameId, level) < maxHintsPerLevel;

  bool get isRewardedAdReady => _ads.isRewardedAdReady;

  /// Runs the rewarded-ad exchange. Returns true when a hint was earned.
  /// Must only be called from an explicit user action (the sheet's button).
  Future<bool> earnHint(String gameId, int level) async {
    if (!canShowHint(gameId, level)) return false;
    final earned = await _ads.showRewardedAd();
    if (!earned) return false;
    await _storage.setInt(_key(gameId, level), hintsUsedFor(gameId, level) + 1);
    _progress.recordHintUsed();
    return true;
  }
}
