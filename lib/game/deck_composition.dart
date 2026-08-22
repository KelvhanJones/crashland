/// Official component counts for Planecrash Survival.
/// Tweak per-type breakdowns as we add cards; keep these totals in sync.
class DeckComposition {
  DeckComposition._();

  static const int forage = 109;
  static const int night = 41; // includes 1 Rescue
  static const int madness = 21;
  static const int craftAndGuides = 16;
  static const int wreckage = 9;

  /// Forage breakdown (must sum to [forage]).
  static const int wood = 22;
  static const int stone = 12;
  static const int fiber = 12;
  static const int bonePile = 9;
  static const int seagull = 1;
  static const int moose = 1;
  static const int waspNest = 1;
  static const int poisonousMushrooms = 1;
  static const int paralysisMushroom = 1;
  static const int neurotoxicMushroom = 1;
  static const int magicalMushrooms = 1;
  static const int psychotropicMushrooms = 1;
  static const int grub = 4;
  static const int wildOnion = 4;
  static const int wildParsnip = 3;
  static const int berries = 4;
  static const int currants = 4;
  static const int squirrel = 3;
  static const int wildPlum = 3;
  static const int minnows = 3;
  static const int chanterelle = 4;
  static const int pineNuts = 5;
  static const int honeycomb = 2;
  static const int trout = 2;
  static const int rabbit = 2;
  static const int dandelion = 3;

  /// Night threats before Rescue (must be [night] - 1).
  static const int nightThreats = night - 1; // 40

  /// Madness: 8 heart-loss cards + roleplay prompts (must sum to [madness]).
  static const int madnessHeartLoss = 8;
  static const int madnessRoleplay = madness - madnessHeartLoss;

  /// Spear / basket / shelter are concurrent deck cards and return when used.
  /// Campfire is a single camp action (1 wood), not a craft-deck card.
  static const int craftFire = 1;
  static const int craftSpear = 6;
  static const int craftBasket = 6;
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
