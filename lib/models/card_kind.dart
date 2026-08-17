enum CardKind {
  food('Food', '🍒'),
  wood('Wood', '🪵'),
  stone('Stone', '🪨'),
  fiber('Fiber', '🧵'),
  uhOh('Uh-oh', '⚠️'),
  bonePile('Bone', '🦴'),
  wreckage('Wreckage', '✈️');

  const CardKind(this.label, this.emoji);

  final String label;
  final String emoji;
}
