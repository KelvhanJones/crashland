/// A crafted shelter with occupants locked in at creation (max 3).
class BuiltShelter {
  BuiltShelter({required Set<String> occupantIds})
      : occupantIds = Set<String>.unmodifiable(occupantIds);

  final Set<String> occupantIds;

  bool protects(String playerId) => occupantIds.contains(playerId);
}
