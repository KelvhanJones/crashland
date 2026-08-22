import 'game_card.dart';
import 'madness_card.dart';

class Player {
  Player({
    required this.id,
    required this.name,
    this.hearts = 3,
    this.maxHearts = 6,
    this.dead = false,
    List<GameCard>? hand,
    this.hasBasket = false,
    this.spearCount = 0,
    this.cannotTrade = false,
    this.forcedForage,
    this.forcedRest = false,
    this.pendingMadness,
    this.drewMadnessThisNight = false,
    this.armsLocked = false,
    this.immobilized = false,
  }) : hand = List<GameCard>.from(hand ?? const []);

  final String id;
  final String name;
  int hearts;
  final int maxHearts;
  bool dead;
  final List<GameCard> hand;
  bool hasBasket;
  int spearCount;
  bool cannotTrade;
  int? forcedForage;
  bool forcedRest;
  MadnessCard? pendingMadness;
  /// One madness card per night, even if they stay at 1♥ after a roleplay prompt.
  bool drewMadnessThisNight;
  /// Paralysis: cannot use arms until the next dawn.
  bool armsLocked;
  /// Neurotoxin: cannot move or speak until the next dawn.
  bool immobilized;

  /// Cannot craft, play cards, or use wreckage.
  bool get cannotAct => !isAlive || armsLocked || immobilized;

  /// Still in the game. Hearts may be 0 until the next dawn.
  bool get isAlive => !dead;

  bool get hasHealWreckage => hand.any((card) => card.isWreckageHeal);

  bool get canBlockAttack =>
      spearCount > 0 ||
      hand.any((card) => card.wreckage == WreckageAbility.taser);

  List<GameCard> get wreckageCards =>
      hand.where((card) => card.wreckage != null).toList();

  int get forageMax {
    if (!isAlive || hearts <= 0) return 0;
    return hearts.clamp(0, 3);
  }
}
