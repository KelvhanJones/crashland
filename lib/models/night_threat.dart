enum NightThreatType {
  hunger(
    'Empty Stomachs',
    'Everyone needs one food card in the pool.',
    {'food': 1},
    perPlayer: true,
  ),
  cold(
    'Bitter Cold',
    'Build a campfire or contribute 1 wood and 1 flint.',
    {'wood': 1, 'flint': 1},
  ),
  predators(
    'Something Stalks',
    'Build a lookout or contribute 2 wood.',
    {'wood': 2},
    structure: 'lookout',
  ),
  storm(
    'Sudden Storm',
    'Build a shelter or contribute 3 wood.',
    {'wood': 3},
    structure: 'shelter',
  );

  const NightThreatType(
    this.title,
    this.description,
    this.requirements, {
    this.perPlayer = false,
    this.structure,
  });

  final String title;
  final String description;
  final Map<String, int> requirements;
  final bool perPlayer;
  final String? structure;
}
