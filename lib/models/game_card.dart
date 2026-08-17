import 'card_kind.dart';

enum UhOhEffect {
  injury,
  spoiled,
  beast,
}

enum WreckageAbility {
  medkit,
  tarp,
  flare,
  knife,
}

class GameCard {
  const GameCard({
    required this.id,
    required this.name,
    required this.kind,
    this.healValue = 0,
    this.uhOh,
    this.boneIndex,
    this.wreckage,
  });

  final String id;
  final String name;
  final CardKind kind;
  final int healValue;
  final UhOhEffect? uhOh;
  final int? boneIndex;
  final WreckageAbility? wreckage;

  bool get isResource =>
      kind == CardKind.wood || kind == CardKind.stone || kind == CardKind.fiber;

  bool get isFood => kind == CardKind.food;
}
