enum NightEventType {
  none,
  weather,
  animal,
  rescue,
}

/// A night card from the official night deck.
class NightCard {
  const NightCard({
    required this.id,
    required this.title,
    required this.description,
    required this.eventType,
    this.allHearts = 0,
    this.unshelteredHearts = 0,
    this.fireCancels = false,
    this.fireReducesAbsDamageTo,
    this.fireBonusHeal = 0,
    this.destroyShelter = false,
    this.noFireTomorrow = false,
    this.discardOneForage = false,
    this.loseAllFiber = false,
    this.loseAllForage = false,
    this.permanentCave = false,
    this.damageIfHasForage = false,
    this.raccoonChoice = false,
  });

  final String id;
  final String title;
  final String description;
  final NightEventType eventType;

  /// Hearts applied to every living survivor (positive = heal, negative = damage).
  final int allHearts;

  /// Extra damage applied only to unsheltered survivors (typically negative).
  final int unshelteredHearts;

  /// Lit fire cancels heart damage / raccoon choice / forage-holder damage.
  final bool fireCancels;

  /// If fire is lit, absolute all-heart damage is reduced to this value.
  final int? fireReducesAbsDamageTo;

  /// Extra heal when fire is lit (The Score).
  final int fireBonusHeal;

  final bool destroyShelter;
  final bool noFireTomorrow;
  final bool discardOneForage;
  final bool loseAllFiber;
  final bool loseAllForage;
  final bool permanentCave;

  /// Wolverine: only survivors holding a forage card take [allHearts] damage.
  final bool damageIfHasForage;

  /// Raccoons: each survivor discards 1 food or loses 1♥ (unless fire cancels).
  final bool raccoonChoice;

  bool get isRescue => eventType == NightEventType.rescue;

  bool get isWeather => eventType == NightEventType.weather;

  bool get isAnimal => eventType == NightEventType.animal;

  bool get dealsAnimalHeartDamage =>
      isAnimal &&
      (allHearts < 0 || damageIfHasForage) &&
      !raccoonChoice &&
      !discardOneForage;
}
