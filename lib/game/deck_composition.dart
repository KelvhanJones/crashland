/// Official component counts for Planecrash Survival.
/// Tweak per-type breakdowns as we add cards; keep these totals in sync.
class DeckComposition {
  DeckComposition._();

  static const int forage = 103;
  static const int night = 41; // includes 1 Rescue
  static const int madness = 21;
  static const int craftAndGuides = 20;
  static const int wreckage = 9;

  /// Forage breakdown (must sum to [forage]).
  /// Counts are placeholders until the forage list is finalized.
  static const int wildBerries = 19;
  static const int creekFish = 11;
  static const int freshKill = 4;
  static const int fallenBranch = 19;
  static const int riverStone = 16;
  static const int vineCord = 14;
  static const int bonePieces = 4;
  static const int unstableSlope = 6;
  static const int spoiledCache = 5;
  static const int stalkingBeast = 5;

  /// Night threats before Rescue (must be [night] - 1).
  static const int nightThreats = night - 1; // 40

  /// Madness: 8 heart-loss cards + roleplay prompts (must sum to [madness]).
  static const int madnessHeartLoss = 8;
  static const int madnessRoleplay = madness - madnessHeartLoss;

  /// Craft & guide stock (must sum to [craftAndGuides]).
  /// Shelter / basket / spear counts are concurrent: used cards return to the deck.
  static const int craftFire = 5;
  static const int craftSpear = 6;
  static const int craftBasket = 5;
  static const int craftShelter = 2;
  static const int craftGuides = 2;

  /// Wreckage pool (must sum to [wreckage]).
  static const int wreckageTaser = 1;
  static const int wreckageVodka = 1;
  static const int wreckageChocolate = 1;
  static const int wreckageNewspaper = 1;
  static const int wreckageBlanket = 1;
  static const int wreckageTarp = 2;
  static const int wreckageAdrenaline = 1;
  static const int wreckageFlareGun = 1;
}
