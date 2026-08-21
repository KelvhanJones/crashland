enum MadnessKind {
  /// Lose 1 heart immediately.
  heartLoss,
  /// Perform a ridiculous action / roleplay prompt. No mechanical penalty.
  roleplay,
}

class MadnessCard {
  const MadnessCard({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
  });

  final String id;
  final MadnessKind kind;
  final String title;
  final String description;

  bool get losesHeart => kind == MadnessKind.heartLoss;
}
