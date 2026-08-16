# Crashland

A cooperative survival card game for **Android and iOS**, built with **Flutter**. Pass one phone or tablet between 2–4 players: gather resources by day, survive island nights together.

> Crashland is an original game inspired by cooperative survival card games. It is not affiliated with any existing tabletop title.

## Gameplay

- **Day:** Each survivor draws 2 cards, trades with others, contributes to a shared pool, and builds camp structures.
- **Night:** A threat appears. Pay the required resources from the pool (or hands), rely on structures, or lose hearts.
- **Win:** Survive all nights with at least one survivor standing.
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
git commit -m "Initial Crashland Flutter app"
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
