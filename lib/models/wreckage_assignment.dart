/// A wreckage card used during night, assigned by its owner to target survivors.
class WreckageAssignment {
  const WreckageAssignment({
    required this.cardId,
    required this.targetIds,
  });

  final String cardId;
  final List<String> targetIds;
}
