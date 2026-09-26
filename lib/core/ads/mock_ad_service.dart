import 'dart:async';

import 'package:flutter/material.dart';

import 'ad_service.dart';
import '../../app/theme/app_dimens.dart';

/// Offline mock implementation of [AdService].
///
/// Renders a clearly-labelled placeholder overlay with a short countdown to
/// exercise the full rewarded flow (consent → ad → reward) without any SDK.
/// Replace with a real adapter before store release.
class MockAdService implements AdService {
  @override
  bool get isRewardedAdReady => true;

  @override
  Future<void> preloadRewardedAd() async {}

  BuildContext? _context;

  /// The mock needs a context to push its overlay; a real SDK would not.
  void attach(BuildContext context) => _context = context;

  @override
  Future<bool> showRewardedAd() async {
    final context = _context;
    if (context == null) return false;
    final navigator = Navigator.of(context, rootNavigator: true);
    final result = await navigator.push<bool>(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => const MockAdPage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return result ?? false;
  }
}

class MockAdPage extends StatefulWidget {
  const MockAdPage({super.key});

  @override
  State<MockAdPage> createState() => _MockAdPageState();
}

class _MockAdPageState extends State<MockAdPage> {
  static const int _totalSeconds = 3;
  int _remaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.space4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space3,
                    vertical: AppDimens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Text(
                    '$_remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        color: Colors.white24, size: 72),
                    const SizedBox(height: AppDimens.space4),
                    const Text(
                      'Mock ad placeholder',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space1),
                    Text(
                      'A real rewarded ad plays here.\n'
                      'The reward is granted when it finishes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.space5),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Close without reward',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
