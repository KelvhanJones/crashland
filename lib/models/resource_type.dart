enum ResourceType {
  food('Food', '🍒'),
  wood('Wood', '🪵'),
  flint('Flint', '🪨'),
  rope('Rope', '🧵');

  const ResourceType(this.label, this.emoji);

  final String label;
  final String emoji;
}
