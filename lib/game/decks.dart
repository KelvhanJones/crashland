import 'dart:math';

import '../models/card_kind.dart';
import '../models/game_card.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';

class Decks {
  Decks._();

  static List<GameCard> forageDeck(Random random, int Function() nextId) {
    final cards = <GameCard>[];

    void add(int count, GameCard Function(int i) builder) {
      for (var i = 0; i < count; i++) {
        cards.add(builder(i));
      }
    }

    add(14, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Wild Berries',
          kind: CardKind.food,
          healValue: 1,
        ));
    add(8, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Creek Fish',
          kind: CardKind.food,
          healValue: 2,
        ));
    add(3, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Fresh Kill',
          kind: CardKind.food,
          healValue: 3,
        ));
    add(14, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Fallen Branch',
          kind: CardKind.wood,
        ));
    add(12, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'River Stone',
          kind: CardKind.stone,
        ));
    add(10, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Vine Cord',
          kind: CardKind.fiber,
        ));
    add(4, (i) => GameCard(
          id: 'c${nextId()}',
          name: 'Wreck Bone ${i + 1}',
          kind: CardKind.bonePile,
          boneIndex: i + 1,
        ));
    add(4, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Unstable Slope',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.injury,
        ));
    add(3, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Spoiled Cache',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.spoiled,
        ));
    add(3, (_) => GameCard(
          id: 'c${nextId()}',
          name: 'Stalking Beast',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.beast,
        ));

    cards.shuffle(random);
    return cards;
  }

  static List<GameCard> wreckageForPlayers(int count, int Function() nextId) {
    final pool = [
      const (name: 'Med Kit', ability: WreckageAbility.medkit),
      const (name: 'Cargo Tarp', ability: WreckageAbility.tarp),
      const (name: 'Signal Flare', ability: WreckageAbility.flare),
      const (name: 'Cabin Knife', ability: WreckageAbility.knife),
    ];

    return List.generate(count, (index) {
      final item = pool[index % pool.length];
      return GameCard(
        id: 'w${nextId()}',
        name: item.name,
        kind: CardKind.wreckage,
        wreckage: item.ability,
        healValue: item.ability == WreckageAbility.medkit ? 2 : 0,
      );
    });
  }

  static List<NightCard> nightDeck({
    required Random random,
    required int totalNights,
    required int Function() nextId,
  }) {
    final templates = <NightCard Function(String id)>[
      (id) => NightCard(
            id: id,
            kind: NightKind.cold,
            title: 'Bitter Cold',
            description:
                'Without a campfire, every survivor loses 1 heart. Fire protects everyone.',
          ),
      (id) => NightCard(
            id: id,
            kind: NightKind.storm,
            title: 'Sudden Squall',
            description:
                'Weather hits the open ground. Survivors not in Shelter (or under a tarp) lose 1 heart.',
          ),
      (id) => NightCard(
            id: id,
            kind: NightKind.predators,
            title: 'Something Stalks',
            description:
                'If the campfire is lit, the camp is safe. Otherwise each unprotected survivor loses 2 hearts. A spear or knife saves one person and breaks.',
          ),
      (id) => NightCard(
            id: id,
            kind: NightKind.raiders,
            title: 'Voices in the Trees',
            description:
                'A human threat. Each unprotected survivor loses 1 heart. A spear or knife saves one person and breaks.',
          ),
      (id) => NightCard(
            id: id,
            kind: NightKind.downpour,
            title: 'Downpour',
            description:
                'Rain kills the fire. Then weather hits: survivors not in Shelter (or under a tarp) lose 1 heart.',
          ),
    ];

    final deck = <NightCard>[];
    while (deck.length < totalNights - 1) {
      final template = templates[deck.length % templates.length];
      deck.add(template('n${nextId()}'));
    }
    deck.shuffle(random);

    // removeLast() draws from the top, so index 0 is the bottom of the pile.
    // Rescue is shuffled into the bottom 3 cards.
    final rescueSlot = deck.isEmpty ? 0 : random.nextInt(min(3, deck.length + 1));
    deck.insert(
      rescueSlot,
      NightCard(
        id: 'n${nextId()}',
        kind: NightKind.rescue,
        title: 'The Rescue',
        description:
            'Searchlights cut the trees. If anyone still stands, you are saved.',
      ),
    );

    return deck;
  }

  static List<MadnessCard> madnessDeck(Random random, int Function() nextId) {
    final cards = <MadnessCard>[
      MadnessCard(
        id: 'm${nextId()}',
        kind: MadnessKind.lashOut,
        title: 'Lash Out',
        description:
            'Fear takes the wheel. Choose another survivor — they lose 1 heart. They may spend a spear or knife to make you take the hit instead.',
      ),
      MadnessCard(
        id: 'm${nextId()}',
        kind: MadnessKind.hoard,
        title: 'Hoard',
        description: 'You cannot trade cards until you recover to 2 or more hearts.',
      ),
      MadnessCard(
        id: 'm${nextId()}',
        kind: MadnessKind.frenzy,
        title: 'Frenzy',
        description: 'Tomorrow you must forage 3 hearts (if you have them).',
      ),
      MadnessCard(
        id: 'm${nextId()}',
        kind: MadnessKind.collapse,
        title: 'Collapse',
        description: 'Tomorrow you cannot forage. You rest instead.',
      ),
      MadnessCard(
        id: 'm${nextId()}',
        kind: MadnessKind.paranoia,
        title: 'Paranoia',
        description: 'You lose 1 heart immediately.',
      ),
    ];
    cards.shuffle(random);
    return cards;
  }
}
