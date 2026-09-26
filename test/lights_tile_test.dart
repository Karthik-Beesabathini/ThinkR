import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/app/theme/app_colors.dart';
import 'package:thinkr/app/theme/app_theme.dart';
import 'package:thinkr/games/lights/lights_tile.dart';

/// The Lights tile must read as a *bulb*, not a decorative dot, and its ON
/// / OFF states must be distinguishable by icon shape (not color alone).
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: buildAppTheme(AppColors.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 72, height: 72, child: child),
          ),
        ),
      );

  testWidgets('ON renders a filled bulb, OFF an outlined one', (tester) async {
    await tester.pumpWidget(host(
      LightTile(
        lit: true,
        isHint: false,
        accent: GameAccents.lights,
        celebrateTint: AppColors.light.surfaceAlt,
        onTap: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);

    await tester.pumpWidget(host(
      LightTile(
        lit: false,
        isHint: false,
        accent: GameAccents.lights,
        celebrateTint: AppColors.light.surfaceAlt,
        onTap: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
  });

  testWidgets('tapping a tile reports the press', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      LightTile(
        lit: false,
        isHint: false,
        accent: GameAccents.lights,
        celebrateTint: AppColors.light.surfaceAlt,
        onTap: () => taps++,
      ),
    ));
    await tester.tap(find.byType(LightTile));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('the bulb scales with the tile so it stays recognizable',
      (tester) async {
    Future<double?> iconSizeAt(double tile) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(AppColors.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: tile,
              height: tile,
              child: LightTile(
                lit: true,
                isHint: false,
                accent: GameAccents.lights,
                celebrateTint: AppColors.light.surfaceAlt,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tester
          .widget<Icon>(find.byIcon(Icons.lightbulb_rounded))
          .size;
    }

    // A small phone tile and a tablet tile: the bulb keeps the same
    // proportion of the tile instead of a fixed pixel size.
    final small = (await iconSizeAt(48))!;
    final large = (await iconSizeAt(120))!;
    expect(large, greaterThan(small));
    expect(small / 46, closeTo(large / 118, 0.5));
    // Never smaller than the legibility floor, never absurdly large.
    expect(small, greaterThanOrEqualTo(16));
    expect(large, lessThanOrEqualTo(40));
  });
}
