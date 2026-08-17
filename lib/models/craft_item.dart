enum CraftItem {
  fire(
    'Campfire',
    'Warms the whole camp for one night. Goes out at dawn.',
    wood: 1,
  ),
  spear(
    'Spear',
    'Stops one animal or human attack for a single survivor. Breaks after use.',
    wood: 1,
    stone: 1,
  ),
  basket(
    'Basket',
    'Draw one extra forage card when you forage. If you rest, you may draw 1 card instead of recovering a heart.',
    wood: 1,
    fiber: 2,
  ),
  shelter(
    'Shelter',
    'Protects up to 3 survivors from most weather. Lasts until destroyed.',
    wood: 2,
    stone: 2,
    fiber: 2,
  );

  const CraftItem(
    this.label,
    this.description, {
    this.wood = 0,
    this.stone = 0,
    this.fiber = 0,
  });

  final String label;
  final String description;
  final int wood;
  final int stone;
  final int fiber;

  Map<String, int> get cost => {
        if (wood > 0) 'wood': wood,
        if (stone > 0) 'stone': stone,
        if (fiber > 0) 'fiber': fiber,
      };
}
