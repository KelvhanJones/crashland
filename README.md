# Planecrash Survival

A cooperative survival card game for **Android, iOS, and Windows**, built with **Flutter**. Play pass-and-play on one device, or host a camp on Wi‑Fi so each survivor uses their own phone.

> Planecrash Survival is an original game. It is not affiliated with any existing tabletop title.

> Planecrash Survival is an original game. It is not affiliated with any existing tabletop title.

## Gameplay

Adapted from classic cooperative crash-survival card game structure.

### Component counts

| Deck | Cards |
|------|------:|
| Forage | 109 |
| Night | 41 (includes Rescue) |
| Madness | 21 |
| Craft & Guides | 16 |
| Wreckage | 9 |

Per-type breakdowns live in `lib/game/deck_composition.dart` and can be tuned as we add cards.

### Rules

- **Setup:** Each survivor starts with 3 hearts, then rolls 3 more (max 6). Everyone gets a wreckage item from the 9-card wreckage pool. Difficulty deals that many nights from the 41-card night deck; Rescue is shuffled into the last 3 night cards.
- **First night:** The game begins at night. The crash has already lit a fire, so the camp is protected by flame until dawn.
- **Forage:** After dawn, flip 1–3 hearts to draw that many forage cards (Basket draws one extra). Rest to recover 1 heart, or if you have a Basket you may rest and draw 1 card instead of healing. You may forage down to **0♥** and stay alive until the **next dawn** — eat food or use a heal wreckage before then, or you die at dawn. Hazards resolve as you draw: a **seagull** does nothing; a **moose** deals 2♥; a **wasp nest** deals 1♥; **poisonous mushrooms** leave you on 1♥; **paralysis** blocks using your arms until the next day; **neurotoxin** blocks moving or speaking until the next day; **magical mushrooms** show the next two night cards; **psychotropic mushrooms** draw a madness card. Four **bone pile** cards can assemble a circle at camp.
- **Camp:** Eat food (2+ heart food can be split), use wreckage heals on any survivor (owner decides), trade, stash cards, and **light the campfire (1 wood)** — there is only one fire, not a craft-deck card. Craft from a limited concurrent stock: **Spear ×6 (1 wood + 1 stone)**, **Basket ×6 (1 wood + 2 fiber)**, or **Shelter ×2 (2 wood + 2 stone + 2 fiber)**. Each shelter covers up to **3 survivors**. With fewer than 4 survivors everyone is covered; with 4, choose who. Used or destroyed craft cards return to the craft deck. Four bone pile cards assemble a circle that can revive someone.
- **Wreckage:** Owners choose who benefits. **Taser** (reusable) or spear blocks 1 animal/human attack. **Flare Gun** protects the whole camp from 1 animal attack. **Tarp** (reusable), **Airline Blanket**, and **Newspaper** (2 players) block weather. **Vodka** (+3♥, shareable), **Chocolate** (+3♥, no split), and **Adrenaline** (full heal) restore hearts.
- **Later nights:** Flip a night card from the 41-card deck (weather, animal, or quiet events). Fire can cancel or soften some threats. Shelter and wreckage protect against weather; spears, taser, and flare gun help against animal attacks. Food and heal wreckage can be used during night before you resolve. Some weather bans fire for the next night. **The Cave** grants permanent shelter for everyone. **The Rescue** wins the game.
- **Madness:** Anyone at 1 heart after night draws **one** madness card. **8 cards** cost 1♥; the other **13** are ridiculous roleplay prompts (talk like a pirate, sing everything, etc.) with no mechanical penalty.
- **Win:** At least one survivor is alive when **The Rescue** appears.
- **Lose:** Everyone reaches 0 hearts.

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- Android Studio / Xcode for device builds

If Flutter is not on your PATH yet, this project was scaffolded with Flutter at:

```text
C:\Users\John\flutter
```

Add that `bin` folder to your PATH, or run commands with the full path.

## Run locally

```bash
cd crashland
flutter pub get
flutter run
```

### Multi-device (same Wi‑Fi)

1. One player taps **Host on this device** and shares the IP shown in the lobby.
2. Everyone else taps **Join another device** and enters that IP plus their name.
3. Host taps **Start expedition** when at least two survivors are seated.

Windows may prompt to allow the app through the firewall. Phones and the host must be on the same network.

### Android

Connect a device or start an emulator, then:

```bash
flutter run -d android
```

### iOS (macOS only)

```bash
flutter run -d ios
```

## GitHub

Remote repository:

```text
https://github.com/KelvhanJones/crashland
```

### First-time push

If the repo does not exist yet on GitHub:

1. Sign in at [github.com/new](https://github.com/new)
2. Create a repository named **crashland** (public or private)
3. Do **not** initialize with a README (this project already has one)
4. From this folder:

```bash
git init
git add .
git commit -m "Initial Planecrash Survival Flutter app"
git branch -M main
git remote add origin https://github.com/KelvhanJones/crashland.git
git push -u origin main
```

## Project structure

```text
lib/
  game/          # Rules engine and game state
  models/        # Cards, players, threats, structures
  screens/       # Home, setup, and game UI
  theme/         # Colors and Material theme
  widgets/       # Reusable UI pieces
```

## License

Private project — add a license when you are ready to publish.
