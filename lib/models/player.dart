import 'game_card.dart';
import 'madness_card.dart';

class Player {
  Player({
    required this.id,
    required this.name,
    this.hearts = 3,
    this.maxHearts = 6,
    List<GameCard>? hand,
    this.hasBasket = false,
    this.spearCount = 0,
    this.knifeCount = 0,
    this.tarpCharges = 0,
    this.flareCharges = 0,
    this.cannotTrade = false,
    this.forcedForage,
    this.forcedRest = false,
    this.pendingMadness,
  }) : hand = List<GameCard>.from(hand ?? const []);

  final String id;
  final String name;
  int hearts;
  final int maxHearts;
  final List<GameCard> hand;
  bool hasBasket;
  int spearCount;
  int knifeCount;
  int tarpCharges;
  int flareCharges;
  bool cannotTrade;
  int? forcedForage;
  bool forcedRest;
  MadnessCard? pendingMadness;

  bool get isAlive => hearts > 0;

  int get forageMax {
    if (!isAlive) return 0;
    return hearts.clamp(0, 3);
  }
}
