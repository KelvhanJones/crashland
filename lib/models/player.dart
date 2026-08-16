import 'game_card.dart';

class Player {
  Player({
    required this.id,
    required this.name,
    this.hearts = 3,
    List<GameCard>? hand,
  }) : hand = List<GameCard>.from(hand ?? const []);

  final String id;
  final String name;
  int hearts;
  final List<GameCard> hand;

  bool get isAlive => hearts > 0;

  Player copyWith({
    String? id,
    String? name,
    int? hearts,
    List<GameCard>? hand,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      hearts: hearts ?? this.hearts,
      hand: hand ?? List<GameCard>.from(this.hand),
    );
  }
}
