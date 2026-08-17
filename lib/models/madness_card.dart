enum MadnessKind {
  lashOut,
  hoard,
  frenzy,
  collapse,
  paranoia,
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
}
