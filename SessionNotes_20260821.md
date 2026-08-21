# Session notes — 21 August 2026

**Project:** Planecrash Survival  
**Repo:** https://github.com/KelvhanJones/crashland  
**Local path:** `C:\Users\John\crashland`  
**Stack:** Flutter / Dart (Android, iOS, Windows)  
**Earlier notes:** `SessionNotes_20260816.md`

---

## Goal

Keep iterating the tabletop rules in the app, then stop requiring one shared phone. Survivors should be able to play on their own devices.

---

## Forage cards — parked

John still needs to go through the forage list. Nothing in the forage deck was rewritten this session.

Current totals (placeholder breakdown) live in `lib/game/deck_composition.dart` and must still sum to **103**:

| Card | Count |
|------|------:|
| Wild Berries | 19 |
| Creek Fish | 11 |
| Fresh Kill | 4 |
| Fallen Branch | 19 |
| River Stone | 16 |
| Vine Cord | 14 |
| Bone pieces | 4 |
| Unstable Slope | 6 |
| Spoiled Cache | 5 |
| Stalking Beast | 5 |

When the new list is ready, update that file (and `Decks.forageDeck`) and keep the 103 total in sync.

---

## Multi-device play (same Wi‑Fi)

Pass-and-play is still there. Home now also supports a **host + join** camp so each player uses their own phone/PC.

| Home button | What it does |
|-------------|--------------|
| **Pass-and-play** | One device, same as before |
| **Host on this device** | Host name, player count, difficulty → lobby with this machine’s IP |
| **Join another device** | Enter host IP + your name → wait in lobby |

**How it works**

1. Host and joiners must be on the **same Wi‑Fi**.
2. Host shares the lobby address (`IP:7384`).
3. Joiners connect; seats fill as `p0` (host), then `p1`, `p2`, …
4. Host starts when at least **2** survivors are seated (up to the chosen 2–4).
5. The **host device runs the real game**. Other devices send actions and receive a full state snapshot.
6. Each networked device only shows **that player’s hand**. Hearts and camp stay visible. Forage buttons only appear on the current player’s device. At night, joiners send their own defenses; the host resolves.

Windows may ask to allow the firewall the first time. This is **LAN only**, not play over the internet.

### New / changed files

| File | Role |
|------|------|
| `lib/game/game_codec.dart` | JSON encode/decode of `GameState` |
| `lib/game/game_engine.dart` | `restore()`, `idCursor`, craft/basket/spear use a chosen `playerId` (not only the current forage player) |
| `lib/net/game_action.dart` | Action payloads + night-prep merge |
| `lib/net/table_session.dart` | WebSocket host (port **7384**) and client |
| `lib/screens/join_screen.dart` | Join by IP |
| `lib/screens/lobby_screen.dart` | Waiting room; host starts the game |
| `lib/screens/home_screen.dart` | Three start paths |
| `lib/screens/setup_screen.dart` | Host flow only asks for the host’s name |
| `lib/screens/game_screen.dart` | Per-device view (`You` / `Active`), networked actions |
| `android/.../AndroidManifest.xml` | Internet / Wi‑Fi permissions |
| `ios/Runner/Info.plist` | Local-network usage + allows local networking |

Packages added: `shelf`, `shelf_web_socket`, `web_socket_channel`.

---

## Rules already in the engine (snapshot)

These were already the live rules by this session; they differ from the 16 August notes.

**Hearts**
- Start 3, then roll up to 3 more (max 6).
- Forage 1–3 hearts. You may go to **0♥** and stay alive until **next dawn**.

**Craft (concurrent stock; used cards return)**

| Item | Count | Cost | Returns when |
|------|------:|------|----------------|
| Campfire | 5 | 1 wood | Dawn, or weather that bans fire (puts it out immediately) |
| Spear | 6 | 1 wood + 1 stone | After blocking an attack |
| Basket | 5 | 1 wood + 2 fiber | Owner dies |
| Shelter | 2 | 2+2+2 | Destroyed by certain nights |

Shelter occupants (1–3) are chosen **when you craft** and stay locked until the shelter is wrecked. **The Cave** is permanent shelter for everyone.

**Wreckage pool (9):** Taser, Vodka, Chocolate, Newspaper, Blanket, Tarp ×2, Adrenaline, Flare Gun. Owners choose who benefits.

**Night:** 41 named cards including Rescue (shuffled into the last 3 of the dealt nights). Difficulty 8 / 12 / 16.

**Madness:** 21 cards — 8 heart-loss, 13 roleplay. One card per player per night.

**UI:** Pinned roster grid (hearts + mini cards), camp as a same-size cell, action log from the banner.

---

## Tests

`flutter test` — 13 passing, including a codec round-trip of a started expedition. Home screen now looks for **Pass-and-play** / **Host on this device** instead of “New Expedition”.

---

## How to run (Windows)

```powershell
$env:Path += ";C:\Users\John\flutter\bin"
cd C:\Users\John\crashland
flutter run -d windows
```

To try two seats on one PC: run the app twice (or Windows + a phone on the same Wi‑Fi). Host on one, join the other with the printed IP.

---

## Still open / next

- **Forage card list** — John to supply; then update `deck_composition.dart` + deck builder
- **Internet multiplayer** — not started (needs a hosted server or similar; LAN host/join is the current path)
- Reconnect / drop handling is thin (lobby marks disconnects; no mid-game reclaim)
- Night resolve still depends on the host tapping **Resolve night** after others send choices
- iOS debug still needs a Mac + Xcode
- No custom card art yet
- README project-structure blurb does not yet list `lib/net/`
