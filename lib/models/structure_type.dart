enum StructureType {
  fire('Campfire', 'Warms the group on cold nights.', {'wood': 1, 'flint': 1}),
  shelter('Shelter', 'Protects everyone from storms.', {'wood': 3}),
  lookout('Lookout', 'Scares off predators at night.', {'wood': 2, 'rope': 1});

  const StructureType(this.label, this.description, this.cost);

  final String label;
  final String description;
  final Map<String, int> cost;
}
