// Display labels and dot colours for the four primary attributes, shared by
// the Heroes grid filters and the Hero detail page's Attributes card —
// approximating the in-game attribute colours (original artwork — no Valve
// assets, ADR-0001).

import 'package:flutter/widgets.dart';

import 'hero_index.dart';

/// Display labels for the four primary attributes, matching the in-game
/// names from the glossary.
const Map<PrimaryAttribute, String> primaryAttributeLabels = {
  PrimaryAttribute.strength: 'Strength',
  PrimaryAttribute.agility: 'Agility',
  PrimaryAttribute.intelligence: 'Intelligence',
  PrimaryAttribute.universal: 'Universal',
};

/// Chip/dot colours in the app's own palette.
const Map<PrimaryAttribute, Color> primaryAttributeColors = {
  PrimaryAttribute.strength: Color(0xFFE04B3F),
  PrimaryAttribute.agility: Color(0xFF5DBB63),
  PrimaryAttribute.intelligence: Color(0xFF4FA3E3),
  PrimaryAttribute.universal: Color(0xFFD9B44A),
};
