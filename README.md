# Planecrash Survival

A cooperative survival card game for **Android, iOS, and Windows**, built with **Flutter**. Pass one device between 2–4 players.

> Planecrash Survival is an original game. It is not affiliated with any existing tabletop title.

## Gameplay

Adapted from classic cooperative crash-survival card game structure:

- **Setup:** Each survivor starts with 3 hearts, then rolls 3 more (max 6). Everyone gets a wreckage item. Rescue is shuffled into the last 3 night cards.
- **First night:** The game begins at night. The crash has already lit a fire, so the camp is protected by flame until dawn.
- **Forage:** After dawn, flip 1–3 hearts to draw that many forage cards (Basket draws one extra). Rest to recover 1 heart, or if you have a Basket you may rest and draw 1 card instead of healing. Foraging on your last heart without finding food is fatal.
- **Camp:** Eat food (2+ heart food can be split), trade, stash cards, and craft **Campfire (1 wood)**, **Spear (1 wood + 1 stone)**, **Basket (1 wood + 2 fiber)**, or **Shelter (2 wood + 2 stone + 2 fiber)**. Four bone pieces assemble a circle that can revive someone.
- **Later nights:** Flip a night card. Fire, shelter, spears, and wreckage can protect you. Fire goes out at dawn, so you must rebuild it.
- **Madness:** Anyone at 1 heart after night draws a madness effect.
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
