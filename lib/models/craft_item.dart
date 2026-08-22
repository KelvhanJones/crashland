enum CraftItem {
  fire(
    'Campfire',
    'One campfire. Costs 1 wood to light. Goes out at dawn. Not a craft-deck card.',
    wood: 1,
  ),
  spear(
    'Spear',
    'Give to any survivor. Stops one animal or human attack for them. Breaks after use and returns to the craft deck.',
    wood: 1,
    stone: 1,
  ),
  basket(
    'Basket',
    'Give to a survivor who does not already have one. Draw one extra forage card when you forage. If you rest, you may draw 1 card instead of recovering a heart. Returns to the craft deck if its owner dies.',
    wood: 1,
    fiber: 2,
  ),
  shelter(
    'Shelter',
    'Protects up to 3 survivors from most weather. With fewer than 4 survivors, everyone is covered. With 4, choose who. Some night cards destroy it — then it returns to the craft deck.',
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
