enum NightKind {
  rescue,
  cold,
  storm,
  predators,
  raiders,
  downpour,
}

class NightCard {
  const NightCard({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
  });

  final String id;
  final NightKind kind;
  final String title;
  final String description;

  bool get isRescue => kind == NightKind.rescue;
}
