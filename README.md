# Thinkr

> **Easy to play. Hard to think.**

A premium collection of quietly difficult puzzle games in a single,
cohesive Flutter app. The controls take seconds to learn; the puzzles
take real thought to solve.

## Current games

| Game | Interaction | Board |
|---|---|---|
| **Shift** | Tap tiles to slide them into order | 3×3 → 5×5, scramble depth ramps with level |
| **Lights** | Tap a tile to flip it and its neighbors | 3×3 → 5×5, deterministic per level |
| **Memory** | Watch a pattern flash, then rebuild it | Solo pattern recall + **2-player duel** on one device — or across two phones nearby |

More games (One Line, Number Path, Pattern, Split) are registered as
quiet "coming soon" entries — adding a real game never touches
navigation or shared UI.

## Architecture

```
lib/
├── main.dart                  # boots storage + services, no onboarding
├── app/
│   ├── app.dart               # ThinkrApp: theme + ServiceScope + AppShell
│   ├── router.dart            # one consistent quick transition
│   └── theme/                 # semantic colors, type scale, spacing tokens
├── core/
│   ├── design_system/         # AppScaffold, GameCard, LevelTile, buttons,
│   │   └── sheets/            #   sheets, nav bar — shared by every game
│   ├── models/                # GameDefinition, PuzzleSession, progress data
│   ├── services/              # registry, progress, settings, daily, hints
│   ├── storage/               # LocalStorage (SharedPreferences wrapper)
│   ├── ads/                   # AdService interface + offline mock
│   ├── audio/                 # settings-aware, silent in v1
│   └── haptics/               # centralized, settings-aware
├── features/
│   ├── shell/                 # 4 quiet tabs (Games/Duel/Progress/Settings)
│   ├── home/                  # Continue card + game cards
│   ├── game_detail/           # chapters + level grid with 5 states
│   ├── gameplay/              # shared puzzle shell (header, hints, reset,
│   │                          #   completion sheet, still-stuck flow)
│   ├── daily/                 # daily challenge service + streaks (Progress tab)
│   ├── multiplayer/           # pass-and-play hub — Memory duel on one device
│   ├── progress/              # plain numbers, no fake IQ scores
│   └── settings/              # sound, haptics, theme, reduced motion, reset
└── games/
    ├── game_catalog.dart      # the registry — add a game here
    ├── lights/  shift/  memory/   # pure logic + board widget per game
```

### Multiplayer

Two duel modes on the Duel tab:

- **Same phone** — pass-and-play, one device.
- **Two phones nearby** — Android Nearby Connections (Bluetooth/BLE/Wi-Fi
  via Play services) behind the `NearbyConnectionsService` interface.
  Like ads, the SDK never leaks into game code: the duel engine
  (`NearbyHostSession`) is host-authoritative, so the guest only sends
  taps and renders what the host judges. Tested end-to-end against a
  scripted fake transport.

### Game contract

Every game implements `GameDefinition` (id, name, tagline, instructions,
accent, level count, seed → level generator, `createBoard`). Boards talk
to the shared shell through `PuzzleHostBridge` (`move`, `invalidMove`,
`solve`, `requestSupport`) and receive hints via a `HintBridge` — so
monetization, persistence and navigation stay entirely outside games.

### Levels

Levels are generated deterministically from a per-game seed, so every
player sees identical puzzles. Difficulty ramps through concepts (bigger
boards, more pattern cells, deeper scrambles), not just size.

### Monetization rules (enforced by design)

- Ads exist only behind an explicit **Hint → Watch Ad** exchange.
- The ad service is an interface; the shipped implementation is a local
  mock. Nothing in a game ever references an SDK.
- After ~3 real failed attempts the app *offers* help — it never forces
  an ad, and never interrupts an active puzzle.

## Offline-first

All progress, settings, daily state and stats live in
`SharedPreferences` behind one storage wrapper. No network, no account,
no Firebase.

## Development

```bash
flutter pub get
flutter analyze   # zero issues
flutter test      # 28 tests: game logic, services, UI smoke tests
flutter build apk --debug
```


## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
