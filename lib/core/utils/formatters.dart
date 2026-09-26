/// Shared formatting helpers.
library;

/// "01:24" style clock for elapsed play time.
String formatPlayTime(int totalSeconds) {
  final minutes = (totalSeconds ~/ 60).clamp(0, 99);
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
