/// A calm, well-separated palette. Subjects cycle through it as they're added,
/// so consecutive subjects never collide and nobody has to pick a colour.
const subjectPalette = <int>[
  0xFF6366F1, // indigo
  0xFF10B981, // emerald
  0xFFF59E0B, // amber
  0xFFF43F5E, // rose
  0xFF0EA5E9, // sky
  0xFF8B5CF6, // violet
  0xFFF97316, // orange
  0xFF14B8A6, // teal
  0xFFEC4899, // pink
  0xFF64748B, // slate
];

/// Next unused colour, falling back to cycling once the palette is exhausted.
int nextSubjectColor(Iterable<int> taken) {
  final used = taken.toSet();
  for (final c in subjectPalette) {
    if (!used.contains(c)) return c;
  }
  return subjectPalette[used.length % subjectPalette.length];
}

/// Semesters typically open in July or January; guess the nearer one so the
/// date picker starts somewhere sane.
DateTime defaultTermStart() {
  final now = DateTime.now();
  return now.month >= 7
      ? DateTime(now.year, 7, 1)
      : DateTime(now.year, 1, 1);
}
