import 'card_kind.dart';

enum UhOhEffect {
  /// Drawn and discarded; nothing else happens.
  none,
  /// Draw a madness card and follow it immediately.
  drawMadness,
  /// Hearts drop to 1 if the survivor had more than 1.
  setHeartsToOne,
  /// Lose [GameCard.uhOhDamage] hearts. May be [GameCard.blockable].
  loseHearts,
  /// Cannot use hands (cards, craft, wreckage) until the next dawn.
  lockArms,
  /// Cannot move or speak (no camp/gear, skip leftover forage) until the next dawn.
  immobilize,
  /// Reveal the next [GameCard.peekCount] night cards; they stay in the deck.
  peekNights,
}

enum WreckageAbility {
  taser,
  vodka,
  chocolate,
  newspaper,
  blanket,
  tarp,
  adrenaline,
  flareGun;

  bool get reusable => this == taser || this == tarp;

  bool get isHeal =>
      this == vodka || this == chocolate || this == adrenaline;

  bool get canShareHeal => this == vodka;

  bool get blocksAnimalOrHuman => this == taser;

  bool get blocksAnimalCampWide => this == flareGun;

  bool get blocksWeather =>
      this == newspaper || this == blanket || this == tarp;

  int get weatherTargetCount => switch (this) {
        WreckageAbility.newspaper => 2,
        WreckageAbility.blanket || WreckageAbility.tarp => 1,
        _ => 0,
      };

  String get label => switch (this) {
        WreckageAbility.taser => 'Taser',
        WreckageAbility.vodka => 'Bottle of Vodka',
        WreckageAbility.chocolate => 'Chocolate Bar',
        WreckageAbility.newspaper => 'Newspaper',
        WreckageAbility.blanket => 'Airline Blanket',
        WreckageAbility.tarp => 'Tarp',
        WreckageAbility.adrenaline => 'Adrenaline Syringe',
        WreckageAbility.flareGun => 'Flare Gun',
      };

  String get blurb => switch (this) {
        WreckageAbility.taser =>
          'Protects 1 player from 1 animal or human attack. Reusable.',
        WreckageAbility.vodka =>
          'Restores 3 hearts. Can be shared. Single use.',
        WreckageAbility.chocolate =>
          'Restores 3 hearts. No sharing. Single use.',
        WreckageAbility.newspaper =>
          'Protects 2 players from 1 weather event. Single use.',
        WreckageAbility.blanket =>
          'Protects 1 player from 1 weather event. Single use.',
        WreckageAbility.tarp =>
          'Protects 1 player from 1 weather event. Reusable.',
        WreckageAbility.adrenaline =>
          'Fully restores all hearts for 1 player. Single use.',
        WreckageAbility.flareGun =>
          'Protects the whole camp from 1 animal attack. Single use.',
      };
}

class GameCard {
  const GameCard({
    required this.id,
    required this.name,
    required this.kind,
    this.flavor = '',
    this.effectBlurb = '',
    this.healValue = 0,
    this.fullHeal = false,
    this.uhOh,
    this.uhOhDamage = 0,
    this.blockable = false,
    this.peekCount = 0,
    this.boneIndex,
    this.wreckage,
  });

  final String id;
  final String name;
  final String flavor;
  final String effectBlurb;
  final CardKind kind;
  final int healValue;
  final bool fullHeal;
  final UhOhEffect? uhOh;
  final int uhOhDamage;
  final bool blockable;
  final int peekCount;
  final int? boneIndex;
  final WreckageAbility? wreckage;

  bool get isResource =>
      kind == CardKind.wood || kind == CardKind.stone || kind == CardKind.fiber;

  bool get isFood => kind == CardKind.food;

  bool get isWreckageHeal =>
      wreckage != null && (wreckage!.isHeal || fullHeal || healValue > 0);

  /// Forage copies of the same card (wood, stone, food, bones) share a stack.
  bool get canStack =>
      wreckage == null && uhOh == null && (isFood || isResource || kind == CardKind.bonePile);

  String get stackKey => canStack ? '${kind.name}|$name|$healValue' : id;
}
