# Session notes — 16 August 2026

**Project:** Planecrash Survival  
**Repo:** https://github.com/KelvhanJones/crashland  
**Local path:** `C:\Users\John\crashland`  
**Stack:** Flutter / Dart (Android, iOS, Windows)  
**Current branch:** `main`

---

## Goal

Build an original cooperative survival card game for phones (and Windows for local testing). Mechanics follow the Ravine-style loop (forage → camp/craft → night → madness → rescue) without using that game’s name or branding.

---

## What we set up

- Flutter SDK (stable 3.47, Dart 3.13) at `C:\Users\John\flutter`
- GitHub remote: `KelvhanJones/crashland` (not JohnnyRJones)
- GitHub CLI is installed at `C:\Program Files\GitHub CLI\gh.exe` (may not be on PATH in every terminal)
- Feature work went through `cursor/update-github-repo-url`, then merged to **main**. That local feature branch was deleted after the merge.

---

## Product decisions

| Topic | Decision |
|--------|----------|
| Display name | **Planecrash Survival** (package folder still `crashland`) |
| Players | 2–4, pass-and-play on one device |
| Difficulty | 8 / 12 / 16 nights; Rescue shuffled into the last 3 night cards |
| Start | **Night 1**, with the **crash fire already lit** |
| Platforms | Android + iOS targets in the project; Windows added for PC debug |

---

## Rules implemented

**Setup**
- Each survivor: 3 hearts, then rolls 3 more (max 6)
- Each gets a wreckage item (med kit, cargo tarp, signal flare, or cabin knife)

**Forage**
- Flip 1–3 hearts to draw that many cards; Basket adds +1 card when foraging
- Rest: **+1 heart**
- With a Basket, rest is a choice: **Rest +1♥** *or* **draw 1 card and do not heal**
- Last heart with no food = death
- Uh-oh cards resolve immediately

**Camp / craft**
- Eat food (2+ can be split), trade, stash by the fire
- Campfire: **1 wood** (disabled while fire is already lit)
- Spear: **1 wood + 1 stone**
- Basket: **1 wood + 2 fiber**
- Shelter: **2 wood + 2 stone + 2 fiber** (up to 3 occupants)
- Craft buttons disable when materials are missing (label: Need more / Already lit / Built / Owned)
- Four bone pieces → bone circle (revive + heal)

**Night**
- Threats: cold, storm, predators, raiders, downpour, or Rescue
- Fire, shelter, spears, and wreckage can protect
- Fire **goes out at dawn** (must recraft)

**Madness**
- Anyone at 1 heart after night draws an effect (lash out, hoard, frenzy, collapse, paranoia)

**Win / lose**
- Win if anyone is alive when Rescue appears
- Lose if everyone reaches 0 hearts

---

## Bugs fixed today

- Windows: “No Windows desktop project configured” → added `windows/`
- Infinite-width buttons (`Size.fromHeight`) breaking layout on wide screens
- ListTile / CheckboxListTile on a colored action bar
- Action bar Column overflowing (~99k pixels) → `mainAxisSize: min`
- Craft stayed tappable without materials → disabled unless affordable

---

## How to run (Windows)

Flutter may be missing from PATH in a new PowerShell. Either:

```powershell
$env:Path += ";C:\Users\John\flutter\bin"
cd C:\Users\John\crashland
flutter run -d windows
```

or:

```powershell
& "C:\Users\John\flutter\bin\flutter.bat" run -d windows
```

Permanent PATH (then restart the terminal):

```powershell
[Environment]::SetEnvironmentVariable(
  "Path",
  [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Users\John\flutter\bin",
  "User"
)
```

---

## iPhone debugging

This PC is Windows. **You cannot build or debug on a physical iPhone from here.** That needs a Mac + Xcode + a signing team. From Windows, debug with Windows desktop, Chrome, or (after Android Studio) an Android phone.

---

## Still open / next

- Android SDK / Android Studio not installed (`flutter doctor` still flags it)
- iOS device testing needs a Mac
- Remote branch `cursor/update-github-repo-url` may still exist on GitHub after the local delete
- No custom card art yet; UI is functional, not final
- Pass-and-play only (no online multiplayer)
- Basket rest vs collapse (forced rest) only allows healing rest, not the basket draw
