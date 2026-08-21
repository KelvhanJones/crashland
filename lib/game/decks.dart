import 'dart:math';

import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';
import 'deck_composition.dart';

class Decks {
  Decks._();

  static List<GameCard> forageDeck(Random random, int Function() nextId) {
    final cards = <GameCard>[];

    void add(int count, GameCard Function(int i) builder) {
      for (var i = 0; i < count; i++) {
        cards.add(builder(i));
      }
    }

    add(
      DeckComposition.wildBerries,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Wild Berries',
        kind: CardKind.food,
        healValue: 1,
      ),
    );
    add(
      DeckComposition.creekFish,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Creek Fish',
        kind: CardKind.food,
        healValue: 2,
      ),
    );
    add(
      DeckComposition.freshKill,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Fresh Kill',
        kind: CardKind.food,
        healValue: 3,
      ),
    );
    add(
      DeckComposition.fallenBranch,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Fallen Branch',
        kind: CardKind.wood,
      ),
    );
    add(
      DeckComposition.riverStone,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'River Stone',
        kind: CardKind.stone,
      ),
    );
    add(
      DeckComposition.vineCord,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Vine Cord',
        kind: CardKind.fiber,
      ),
    );
    add(
      DeckComposition.bonePieces,
      (i) => GameCard(
        id: 'c${nextId()}',
        name: 'Wreck Bone ${i + 1}',
        kind: CardKind.bonePile,
        boneIndex: i + 1,
      ),
    );
    add(
      DeckComposition.unstableSlope,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Unstable Slope',
        kind: CardKind.uhOh,
        uhOh: UhOhEffect.injury,
      ),
    );
    add(
      DeckComposition.spoiledCache,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Spoiled Cache',
        kind: CardKind.uhOh,
        uhOh: UhOhEffect.spoiled,
      ),
    );
    add(
      DeckComposition.stalkingBeast,
      (_) => GameCard(
        id: 'c${nextId()}',
        name: 'Stalking Beast',
        kind: CardKind.uhOh,
        uhOh: UhOhEffect.beast,
      ),
    );

    assert(
      cards.length == DeckComposition.forage,
      'Forage deck is ${cards.length}, expected ${DeckComposition.forage}',
    );
    cards.shuffle(random);
    return cards;
  }

  static List<GameCard> wreckagePool(int Function() nextId) {
    final cards = <GameCard>[];

    void add(
      int count,
      WreckageAbility ability, {
      int heal = 0,
      bool fullHeal = false,
    }) {
      for (var i = 0; i < count; i++) {
        cards.add(
          GameCard(
            id: 'w${nextId()}',
            name: ability.label,
            kind: CardKind.wreckage,
            wreckage: ability,
            healValue: heal,
            fullHeal: fullHeal,
          ),
        );
      }
    }

    add(DeckComposition.wreckageTaser, WreckageAbility.taser);
    add(DeckComposition.wreckageVodka, WreckageAbility.vodka, heal: 3);
    add(DeckComposition.wreckageChocolate, WreckageAbility.chocolate, heal: 3);
    add(DeckComposition.wreckageNewspaper, WreckageAbility.newspaper);
    add(DeckComposition.wreckageBlanket, WreckageAbility.blanket);
    add(DeckComposition.wreckageTarp, WreckageAbility.tarp);
    add(
      DeckComposition.wreckageAdrenaline,
      WreckageAbility.adrenaline,
      fullHeal: true,
    );
    add(DeckComposition.wreckageFlareGun, WreckageAbility.flareGun);

    assert(
      cards.length == DeckComposition.wreckage,
      'Wreckage pool is ${cards.length}, expected ${DeckComposition.wreckage}',
    );
    return cards;
  }

  /// Deal one wreckage card per player from the 9-card pool.
  static List<GameCard> wreckageForPlayers(
    int playerCount,
    Random random,
    int Function() nextId,
  ) {
    final pool = wreckagePool(nextId)..shuffle(random);
    return pool.take(playerCount.clamp(0, pool.length)).toList();
  }

  static Map<CraftItem, int> craftStock() {
    final stock = {
      CraftItem.fire: DeckComposition.craftFire,
      CraftItem.spear: DeckComposition.craftSpear,
      CraftItem.basket: DeckComposition.craftBasket,
      CraftItem.shelter: DeckComposition.craftShelter,
    };
    final craftTotal = stock.values.fold<int>(0, (sum, n) => sum + n);
    assert(
      craftTotal + DeckComposition.craftGuides ==
          DeckComposition.craftAndGuides,
      'Craft & guides total is ${craftTotal + DeckComposition.craftGuides}, '
      'expected ${DeckComposition.craftAndGuides}',
    );
    return stock;
  }

  static int craftMax(CraftItem item) => switch (item) {
        CraftItem.fire => DeckComposition.craftFire,
        CraftItem.spear => DeckComposition.craftSpear,
        CraftItem.basket => DeckComposition.craftBasket,
        CraftItem.shelter => DeckComposition.craftShelter,
      };

  static List<NightCard> nightDeck({
    required Random random,
    required int totalNights,
    required int Function() nextId,
  }) {
    NightCard card({
      required String title,
      required String description,
      required NightEventType eventType,
      int allHearts = 0,
      int unshelteredHearts = 0,
      bool fireCancels = false,
      int? fireReducesAbsDamageTo,
      int fireBonusHeal = 0,
      bool destroyShelter = false,
      bool noFireTomorrow = false,
      bool discardOneForage = false,
      bool loseAllFiber = false,
      bool loseAllForage = false,
      bool permanentCave = false,
      bool damageIfHasForage = false,
      bool raccoonChoice = false,
    }) {
      return NightCard(
        id: 'n${nextId()}',
        title: title,
        description: description,
        eventType: eventType,
        allHearts: allHearts,
        unshelteredHearts: unshelteredHearts,
        fireCancels: fireCancels,
        fireReducesAbsDamageTo: fireReducesAbsDamageTo,
        fireBonusHeal: fireBonusHeal,
        destroyShelter: destroyShelter,
        noFireTomorrow: noFireTomorrow,
        discardOneForage: discardOneForage,
        loseAllFiber: loseAllFiber,
        loseAllForage: loseAllForage,
        permanentCave: permanentCave,
        damageIfHasForage: damageIfHasForage,
        raccoonChoice: raccoonChoice,
      );
    }

    void add(List<NightCard> into, int count, NightCard Function() build) {
      for (var i = 0; i < count; i++) {
        into.add(build());
      }
    }

    final threats = <NightCard>[];

    // --- None ---
    add(
      threats,
      1,
      () => card(
        title: 'The Cave',
        description: 'Permanent shelter for all survivors.',
        eventType: NightEventType.none,
        permanentCave: true,
      ),
    );
    for (final title in [
      'The Fog',
      'The Dark',
      'The Quiet',
      'The Calm',
      'The Night',
      'The Woods',
    ]) {
      add(
        threats,
        1,
        () => card(
          title: title,
          description: 'A quiet night. Nothing happens.',
          eventType: NightEventType.none,
        ),
      );
    }
    add(
      threats,
      1,
      () => card(
        title: 'The Owl',
        description: 'All survivors recover 1 heart.',
        eventType: NightEventType.none,
        allHearts: 1,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Deer',
        description: 'All survivors recover 3 hearts.',
        eventType: NightEventType.none,
        allHearts: 3,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Score',
        description:
            'All survivors recover 1 heart. A lit fire boosts healing by 1 more.',
        eventType: NightEventType.none,
        allHearts: 1,
        fireBonusHeal: 1,
      ),
    );
    for (final title in [
      'The Guilt',
      'The Voices',
      'The Fear',
      'The Bugs',
      'The Terror',
    ]) {
      add(
        threats,
        1,
        () => card(
          title: title,
          description: 'All survivors lose 1 heart. Fire cancels this event.',
          eventType: NightEventType.none,
          allHearts: -1,
          fireCancels: true,
        ),
      );
    }
    add(
      threats,
      1,
      () => card(
        title: 'The Mountain',
        description: 'All survivors lose 2 hearts. Any shelter is destroyed.',
        eventType: NightEventType.none,
        allHearts: -2,
        destroyShelter: true,
      ),
    );

    // --- Weather ---
    add(
      threats,
      1,
      () => card(
        title: 'The Storm',
        description:
            'Unsheltered survivors lose 2 hearts. Shelter is destroyed. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -2,
        destroyShelter: true,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Drizzle',
        description:
            'Unsheltered survivors lose 1 heart. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Gale',
        description:
            'Unsheltered survivors lose 1 heart. Everyone discards 1 forage card (if any).',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        discardOneForage: true,
      ),
    );
    add(
      threats,
      2,
      () => card(
        title: 'The Wind',
        description:
            'Unsheltered survivors lose 1 heart. All fiber is lost.',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        loseAllFiber: true,
      ),
    );
    add(
      threats,
      3,
      () => card(
        title: 'Heavy Rain',
        description:
            'Unsheltered survivors lose 2 hearts. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -2,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      3,
      () => card(
        title: 'The Rain',
        description:
            'Unsheltered survivors lose 1 heart. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'Light Rain',
        description:
            'Unsheltered survivors lose 1 heart. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Sleet',
        description:
            'Unsheltered survivors lose 1 heart. No fire tomorrow night.',
        eventType: NightEventType.weather,
        unshelteredHearts: -1,
        noFireTomorrow: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Flood',
        description:
            'All collected forage cards are lost. Shelter is destroyed. No fire tomorrow night.',
        eventType: NightEventType.weather,
        loseAllForage: true,
        destroyShelter: true,
        noFireTomorrow: true,
      ),
    );

    // --- Animal ---
    for (final title in ['The Birds', 'Giant Squirrel', 'The Weasels']) {
      add(
        threats,
        1,
        () => card(
          title: title,
          description: 'Everyone discards 1 forage card (if any).',
          eventType: NightEventType.animal,
          discardOneForage: true,
        ),
      );
    }
    add(
      threats,
      1,
      () => card(
        title: 'The Bats',
        description: 'All survivors lose 1 heart. Fire cancels this event.',
        eventType: NightEventType.animal,
        allHearts: -1,
        fireCancels: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Wolves',
        description:
            'All survivors lose 2 hearts. Fire reduces the loss to 1 heart.',
        eventType: NightEventType.animal,
        allHearts: -2,
        fireReducesAbsDamageTo: 1,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'Wolverine',
        description:
            'Anyone with a forage card loses 1 heart. Fire cancels this event.',
        eventType: NightEventType.animal,
        allHearts: -1,
        damageIfHasForage: true,
        fireCancels: true,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Cougar',
        description: 'All survivors lose 2 hearts.',
        eventType: NightEventType.animal,
        allHearts: -2,
      ),
    );
    add(
      threats,
      1,
      () => card(
        title: 'The Bear',
        description: 'All survivors lose 2 hearts. Shelter is destroyed.',
        eventType: NightEventType.animal,
        allHearts: -2,
        destroyShelter: true,
      ),
    );
    add(
      threats,
      2,
      () => card(
        title: 'The Raccoons',
        description:
            'Each survivor discards 1 food card or loses 1 heart. Fire cancels this event.',
        eventType: NightEventType.animal,
        raccoonChoice: true,
        fireCancels: true,
      ),
    );

    assert(
      threats.length == DeckComposition.nightThreats,
      'Night threats are ${threats.length}, expected ${DeckComposition.nightThreats}',
    );
    threats.shuffle(random);

    final nights = totalNights.clamp(1, DeckComposition.night);
    final deck = threats.take(nights - 1).toList();

    final rescueSlot =
        deck.isEmpty ? 0 : random.nextInt(min(3, deck.length + 1));
    deck.insert(
      rescueSlot,
      card(
        title: 'The Rescue',
        description:
            'Searchlights cut the trees. If anyone still stands, you are saved.',
        eventType: NightEventType.rescue,
      ),
    );

    assert(deck.length == nights);
    return deck;
  }

  static List<MadnessCard> madnessDeck(Random random, int Function() nextId) {
    MadnessCard build(MadnessKind kind, String title, String description) {
      return MadnessCard(
        id: 'm${nextId()}',
        kind: kind,
        title: title,
        description: description,
      );
    }

    final heartLoss = <(String, String)>[
      ('Paranoia', 'You lose 1 heart as fear closes in.'),
      ('Panic', 'You lose 1 heart in a sudden spiral.'),
      ('Despair', 'You lose 1 heart — hope feels far away.'),
      ('Nightmare', 'You lose 1 heart to something that was not there.'),
      ('Blackout', 'You lose 1 heart and remember nothing.'),
      ('Vertigo', 'You lose 1 heart as the wreck tilts.'),
      ('Hollow', 'You lose 1 heart. The quiet is too loud.'),
      ('Breakdown', 'You lose 1 heart and can barely stand.'),
    ];

    final roleplay = <(String, String)>[
      (
        'Talk Like a Pirate',
        'Until dawn, you may only speak like a pirate. Arr!',
      ),
      (
        'The Opera',
        'Sing everything you say until your next forage.',
      ),
      (
        'Chicken Dance',
        'Do a quick chicken dance before every action you take this round.',
      ),
      (
        'Royal Decree',
        'Address every other survivor as “Your Majesty” until dawn.',
      ),
      (
        'Whisper Campaign',
        'You may only whisper until you forage or rest.',
      ),
      (
        'Accidental Accent',
        'Pick an accent and keep it until the next night card.',
      ),
      (
        'Narrator Mode',
        'Describe your own actions in dramatic third person.',
      ),
      (
        'The Mime',
        'Communicate without spoken words for one full player turn.',
      ),
      (
        'Conspiracy',
        'Convince the table of a wild theory about the crash — with confidence.',
      ),
      (
        'Camp Counselor',
        'Lead a 10-second pep talk or cheer for the survivors.',
      ),
      (
        'Year 3000',
        'Speak as if you are a time traveler from the distant future.',
      ),
      (
        'Beast Mode',
        'Growl, chirp, or otherwise use only animal sounds for one exchange.',
      ),
      (
        'Confession Booth',
        'Admit a ridiculous (fake) secret about how the plane went down.',
      ),
    ];

    assert(heartLoss.length == DeckComposition.madnessHeartLoss);
    assert(roleplay.length == DeckComposition.madnessRoleplay);

    final cards = <MadnessCard>[
      for (final entry in heartLoss)
        build(MadnessKind.heartLoss, entry.$1, entry.$2),
      for (final entry in roleplay)
        build(MadnessKind.roleplay, entry.$1, entry.$2),
    ];

    assert(
      cards.length == DeckComposition.madness,
      'Madness deck is ${cards.length}, expected ${DeckComposition.madness}',
    );
    cards.shuffle(random);
    return cards;
  }
}
