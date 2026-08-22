# Session notes — 22 August 2026

**Project:** Planecrash Survival  
**Repo:** https://github.com/KelvhanJones/crashland  
**Local path:** `C:\Users\John\crashland`  
**Stack:** Flutter / Dart (Android, iOS, Windows)  
**Earlier notes:** `SessionNotes_20260816.md`, `SessionNotes_20260821.md`

---

## Goal

Catch the app up to the table: campfire, craft stock, food splits, bones, and who gets what. Make targeting work by tapping survivor boxes (phones, no dropdowns). Package a Windows build friends can install. Internet play was discussed and parked.

---

## Shipped on `main`

| Commit | What |
|--------|------|
| `cd4bbb7` | Tap-to-choose survivors; camp / craft / icon / forage rules matched to the table |
| `cb6355f` | Inno Setup recipe; `dist/` and the zip stay out of git |

---

## Rules that changed vs 21 August

The 21 August notes still describe campfire as a craft-deck card (×5) and forage as a parked 103-card placeholder. That is no longer true.

### Forage — 109, list is in the app

John’s forage list is in `lib/game/deck_composition.dart` / `Decks.forageDeck`. Totals must stay at **109**.

| Kind | Count |
|------|------:|
| Fallen Branch (wood) | 22 |
| River Stone | 12 |
| Vine Cord (fiber) | 12 |
| Bone pile | 9 |
| Seagull, moose, wasp nest, poisonous / paralysis / neurotoxic / magical / psychotropic mushrooms | 1 each (8) |
| Foods (grub, onion, parsnip, berries, currants, squirrel, plum, minnows, chanterelle, pine nuts, honeycomb, trout, rabbit, dandelion) | 46 |

**Fresh forage** stays hidden from everyone except the forager until camp / dawn (`freshForageIds`).

**Bones:** 9 undifferentiated bone-pile cards. Four at camp assemble a circle. Foraged bones go **straight to camp** and stay there (nobody can take them). Revive: the dead survivor returns at 3♥; the extra +2♥ only goes to people **already living**.

### Campfire is not a craft card

- Craft & Guides deck is **16**: Spear ×6, Basket ×6, Shelter ×2, Guides ×2.
- There is **one** fire. Light it with **1 wood** (select wood → Light fire in card actions). No camp-panel Light fire button.
- Fire goes out at dawn. Crash night 1 starts with the fire already lit.
- Living players **cannot stash wood**. If someone dies, their whole hand (including wood) dumps to camp, and that wood can light the fire.

### Craft recipients

`GameEngine.craft(..., recipientId:)`. Basket can be crafted for someone else even if you already have one (`canCraft` if anyone lacks a basket). Shelter: fewer than 4 survivors auto-covers everyone; 4 players choose 1–3 occupants.

### Food and wreckage heals

- Engine: `splitHeal` — one or more recipients, total 1..healValue, card from **hand or camp stash**.
- `useHealCard` also finds cards in the camp stash (camp vodka Use/self was a silent no-op before).
- Food +2/+3 and vodka: tap a survivor for **+1♥** each time until the card is spent; **Give N♥** confirms a partial; long-press removes one pending heart.
- Chocolate / adrenaline: one tap dumps the whole heal.
- Matching forage cards stack (`GameCard.stackKey`).

### Hearts (unchanged this session)

Start 3, roll up to 3 more (max 6). Forage down to 0♥; you die at the **next dawn** if still at 0.

---

## Tap-to-choose (device UX)

Survivor boxes are the targeting UI. No “use on / give to” dropdowns.

| After you select… | Tap a survivor box to… |
|-------------------|------------------------|
| Food / vodka | Assign **1♥** (repeat until the card is used) |
| Chocolate / adrenaline | Dump the whole heal |
| A card to give | Immediate trade |
| Spear / basket craft | Who receives it |
| Shelter (4 players) | Occupants (1–3); 3rd tap auto-builds, or **Build (N)** for fewer |
| Night protection (newspaper 2, tarp/blanket 1) | Who it covers |
| Flare | Selecting the card covers camp (no extra tap) |
| Spear at night | The spear-holder who uses it |
| Raccoons | Who discards food instead of 1♥ |

Card taps stay on the mini-card chips. Name/hearts on the box are the hit target so choosing a card does not also assign a heart to its owner.

Roster is always **5 cells**: four player seats (Empty if unused) + Camp. Craft boxes: spear, basket, shelter only.

Widget keys: `ValueKey('player-p0')`, `ValueKey('craft-spear')`.

---

## App icon

`assets/icon/app_icon.png` — night crash-site, campfire, wrecked plane, pines. `flutter_launcher_icons` writes Android / iOS / Windows icons. Home screen uses the same asset.

---

## Internet play — talked through, not built

LAN host/join is unchanged: host phone binds **port 7384**, joiners type a `192.168.x.x` address, host runs `GameEngine`, others send actions and get snapshots (`lib/net/table_session.dart`).

Friends on different networks cannot reach that. A real online mode would be **room code + a small cloud relay** (`wss://`), then reconnect. Moving the engine onto the server is a later step. WebRTC is overkill for this game.

Workaround today: Tailscale (or similar) and join with the Tailscale IP. Not a product path.

---

## Windows packaging

Friends do not need Flutter.

| File | Use |
|------|-----|
| `dist\PlanecrashSurvival-setup.exe` | Installer (~11 MB). Start Menu, optional desktop shortcut, uninstall from Settings |
| `dist\PlanecrashSurvival-windows.zip` | Portable. Unzip and run `crashland.exe` next to `flutter_windows.dll` and `data\` |

Recipe: `installer/planecrash_survival.iss` (Inno Setup 6). Built copies are gitignored (`/dist/`, `/PlanecrashSurvival-windows.zip`).

Inno lives at `%LOCALAPPDATA%\Programs\Inno Setup 6\` on this PC (winget user install, not Program Files).

```powershell
$env:Path += ";C:\Users\John\flutter\bin"
cd C:\Users\John\crashland
flutter build windows --release
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\planecrash_survival.iss
```

Windows may show SmartScreen (unsigned). **More info → Run anyway.** If it fails to start, install the [VC++ x64 redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist). Hosting on Wi‑Fi may prompt for firewall access.

---

## Key files this session

| File | Role |
|------|------|
| `lib/game/deck_composition.dart` | 109 forage, 16 craft (no fire in the deck) |
| `lib/game/game_engine.dart` | `craft` recipient, `lightFire`, `splitHeal`, bones to camp, wood dump on death |
| `lib/screens/game_screen.dart` | Roster, `_tapPlayer`, pending craft / heal / night protect |
| `lib/widgets/heart_display.dart` | Pending amber hearts |
| `lib/widgets/resource_card_tile.dart` | Mini cards / stacks |
| `lib/net/game_action.dart` | `lightFire`, craft `recipientId`, split food |
| `lib/models/game_card.dart` | `canStack` / `stackKey` |
| `assets/icon/app_icon.png` | App icon |
| `installer/planecrash_survival.iss` | Windows setup |

---

## Tests

Last full run this work: **`flutter test` — 33 passed**.

Notes for later: camp vodka `useHealCard` from camp; spear craft is tap `craft-spear` then `player-p1` (not a “Choose who” popup). “Foraging to 0♥ … heal wreckage” can flake if forage draws paralysis (arms locked) — RNG, pre-existing.

---

## Still open / next

- **Internet multiplayer** — design is room code + relay; not started
- Reconnect / host-drop is still thin (host phone is the authority)
- Night resolve still waits on the host tapping **Resolve night**
- No code-signed Windows build (SmartScreen warning)
- iOS debug still needs a Mac + Xcode
- No custom card art yet
- README still has a duplicated affiliation disclaimer
