// Synthetic herodata feed builders, mirroring the live feed's shape
// (verified 2026-10-21 against `herodata?language=english&hero_id=1`),
// trimmed to the fields the converter reads. Display strings (behavior tag,
// targeting, damage, dispel) replicate Valve's own decode tables extracted
// from dota2.com's front-end `main.js`, so the app shows what the official
// site shows.
//
// Shared by the converter test and the refresh-unit test so the synthetic
// feed can't drift between the two.

/// One special value, in feed shape.
Map<String, Object?> specialValue(
  String name, {
  required List<double> valuesFloat,
  String heading = '',
  bool isPercentage = false,
  List<double> valuesShard = const [],
  List<double> valuesScepter = const [],
  List<Map<String, Object?>> bonuses = const [],
  String facetBonusName = '',
  List<double> facetBonusValues = const [],
}) => {
  'name': name,
  'values_float': valuesFloat,
  'is_percentage': isPercentage,
  'heading_loc': heading,
  'bonuses': bonuses,
  'values_shard': valuesShard,
  'values_scepter': valuesScepter,
  'facet_bonus': {
    'name': facetBonusName,
    'values': facetBonusValues,
    'operation': 0,
  },
  'required_facet': '',
};

/// One ability, in feed shape.
Map<String, Object?> ability({
  required String name,
  required String nameLoc,
  String descLoc = 'Does a thing.',
  String loreLoc = '',
  List<String> notesLoc = const [],
  String shardLoc = '',
  String scepterLoc = '',
  List<String> facetsLoc = const ['', ''],
  String behavior = '4',
  int immunity = 0,
  int targetTeam = 0,
  int targetType = 0,
  int damage = 0,
  int dispellable = 0,
  int maxLevel = 4,
  int type = 0,
  List<double> castRanges = const [0],
  List<double> manaCosts = const [0],
  List<double> cooldowns = const [0],
  List<double> damages = const [0, 0, 0, 0],
  List<Map<String, Object?>> specialValues = const [],
  bool isInnate = false,
  bool grantedByScepter = false,
  bool grantedByShard = false,
}) => {
  'id': 5003,
  'name': name,
  'name_loc': nameLoc,
  'desc_loc': descLoc,
  'lore_loc': loreLoc,
  'notes_loc': notesLoc,
  'shard_loc': shardLoc,
  'scepter_loc': scepterLoc,
  'facets_loc': facetsLoc,
  'type': type,
  'behavior': behavior,
  'target_team': targetTeam,
  'target_type': targetType,
  'flags': 0,
  'damage': damage,
  'immunity': immunity,
  'dispellable': dispellable,
  'max_level': maxLevel,
  'cast_ranges': castRanges,
  'cast_points': const [0],
  'channel_times': const [0],
  'cooldowns': cooldowns,
  'durations': const [0],
  'damages': damages,
  'mana_costs': manaCosts,
  'gold_costs': const [],
  'health_costs': const [],
  'special_values': specialValues,
  'is_item': false,
  'ability_has_scepter': false,
  'ability_has_shard': false,
  'ability_is_granted_by_scepter': grantedByScepter,
  'ability_is_granted_by_shard': grantedByShard,
  'ability_is_innate': isInnate,
  'item_cost': 0,
  'item_initial_charges': 0,
  'item_neutral_tier': 4294967295,
  'item_stock_max': 0,
  'item_stock_time': 0,
  'item_quality': 0,
};

/// A talent, in feed shape (name_loc carries `{s:…}` tokens).
Map<String, Object?> talent(
  String name,
  String nameLoc, {
  List<Map<String, Object?>> specialValues = const [],
}) => ability(
  name: name,
  nameLoc: nameLoc,
  behavior: '2',
  type: 2,
  specialValues: specialValues,
);

Map<String, Object?> facet(String name, {required String titleLoc}) => {
  'name': name,
  'title_loc': titleLoc,
  'description_loc': '',
  'color': 0,
  'icon': 'magebanes_mirror',
  'gradient_id': 0,
};

/// The four base abilities + eight talents, in live-feed shape (Anti-Mage,
/// trimmed). Ability names/tokens match the real feed so every resolved
/// string below is what dota2.com itself renders.
List<Object?> baseAbilities() => [
  ability(
    name: 'antimage_mana_break',
    nameLoc: 'Mana Break',
    descLoc:
        'Burns mana equal to %percent_damage_per_burn%%% of the mana burnt as '
        'damage. Burns %mana_per_hit% mana per hit, up to '
        '%mana_per_hit_pct%%% of max mana.',
    loreLoc: 'A modified technique of peaceful ways.',
    notesLoc: const ['25% mana burn from illusions.'],
    behavior: '2',
    immunity: 4,
    specialValues: [
      specialValue(
        'percent_damage_per_burn',
        valuesFloat: [65],
        heading: 'MANA BURNED AS DAMAGE:',
      ),
      specialValue(
        'mana_per_hit',
        valuesFloat: [25, 30, 35, 40],
        heading: 'MANA BURNED PER HIT:',
      ),
      specialValue(
        'mana_per_hit_pct',
        valuesFloat: [1.8, 2.7, 3.6, 4.5],
        heading: 'MAX MANA BURNED PER HIT:',
        isPercentage: true,
      ),
      specialValue('illusion_percentage', valuesFloat: [25]),
    ],
  ),
  ability(
    name: 'antimage_blink',
    nameLoc: 'Blink',
    descLoc: 'Short distance teleportation.',
    behavior: '274878431248',
    castRanges: const [875, 950, 1025, 1100],
    manaCosts: const [60, 55, 50, 45],
    cooldowns: const [10.5, 9, 7.5, 6],
    scepterLoc:
        'After casting Blink, your next Mana Break burns an additional '
        '%empowered_max_burn_tooltip%%% max mana.',
    specialValues: [
      specialValue(
        'AbilityCastRange',
        valuesFloat: const [875, 950, 1025, 1100],
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_3',
            'value': 125,
            'operation': 0,
          },
        ],
      ),
      specialValue(
        'empowered_max_burn_tooltip',
        valuesFloat: const [0],
        valuesScepter: const [20],
      ),
      specialValue(
        'AbilityCooldown',
        valuesFloat: const [10.5, 9, 7.5, 6],
        bonuses: [
          {'name': 'special_bonus_unique_antimage', 'value': 1, 'operation': 2},
        ],
      ),
    ],
  ),
  ability(
    name: 'antimage_persectur',
    nameLoc: 'Persecutor',
    descLoc: 'Attacks slow enemies based on missing mana.',
    behavior: '8796093022274',
    maxLevel: 1,
    isInnate: true,
    specialValues: [
      specialValue(
        'move_slow_min',
        valuesFloat: const [12],
        isPercentage: true,
        heading: 'MIN MOVEMENT SLOW:',
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_5',
            'value': 9,
            'operation': 0,
          },
        ],
      ),
      specialValue(
        'move_slow_max',
        valuesFloat: const [24],
        isPercentage: true,
        heading: 'MAX MOVEMENT SLOW:',
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_5',
            'value': 18,
            'operation': 0,
          },
        ],
      ),
    ],
  ),
  ability(
    name: 'antimage_mana_void',
    nameLoc: 'Mana Void',
    descLoc: 'Damages based on missing mana.',
    behavior: '40',
    immunity: 4,
    targetTeam: 2,
    targetType: 19,
    damage: 2,
    maxLevel: 3,
    type: 1,
    castRanges: const [600],
    manaCosts: const [100, 150, 200],
    cooldowns: const [100, 85, 70],
    specialValues: [
      specialValue(
        'mana_void_aoe_radius',
        valuesFloat: const [400, 450, 500],
        heading: 'RADIUS:',
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_manavoid_aoe',
            'value': 200,
            'operation': 0,
          },
        ],
      ),
      specialValue(
        'mana_void_damage_per_mana',
        valuesFloat: const [1],
        heading: 'DAMAGE PER 1 MANA MISSING:',
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_6',
            'value': 0.2,
            'operation': 0,
          },
        ],
      ),
      specialValue(
        'mana_void_ministun',
        valuesFloat: const [0.3],
        heading: 'STUN DURATION:',
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_8',
            'value': 0.8,
            'operation': 0,
          },
        ],
      ),
      specialValue(
        'AbilityCooldown',
        valuesFloat: const [100, 85, 70],
        bonuses: [
          {
            'name': 'special_bonus_unique_antimage_2',
            'value': 50,
            'operation': 2,
          },
        ],
      ),
    ],
  ),
];

List<Object?> baseTalents() => [
  talent(
    'special_bonus_hp_regen_3',
    '+{s:value} Health Regen',
    specialValues: [
      specialValue('value', valuesFloat: const [3]),
    ],
  ),
  talent(
    'special_bonus_unique_antimage_manavoid_aoe',
    '+{s:bonus_mana_void_aoe_radius} Mana Void Radius',
  ),
  talent(
    'special_bonus_unique_antimage_5',
    '+{s:bonus_move_slow_min}%/{s:bonus_move_slow_max}% Persecutor Min/Max '
        'Movement Slow',
  ),
  talent(
    'special_bonus_unique_antimage_6',
    '+{s:bonus_mana_void_damage_per_mana} Mana Void Damage Multiplier',
  ),
  talent(
    'special_bonus_unique_antimage_3',
    '+{s:bonus_AbilityCastRange} Blink Cast Range',
  ),
  talent(
    'special_bonus_unique_antimage',
    '-{s:bonus_AbilityCooldown}s Blink Cooldown',
  ),
  talent(
    'special_bonus_unique_antimage_8',
    '+{s:bonus_mana_void_ministun}s Mana Void Stun',
  ),
  talent(
    'special_bonus_unique_antimage_2',
    '-{s:bonus_AbilityCooldown}s Mana Void Cooldown',
  ),
];

/// The hero document, in feed shape.
Map<String, Object?> heroFeed({
  List<Object?> facets = const [],
  List<Object?>? abilities,
  List<Object?>? talents,
  List<Object?>? facetAbilities,
}) => {
  'id': 1,
  'name': 'npc_dota_hero_antimage',
  'order_id': 1,
  'name_loc': 'Anti-Mage',
  'bio_loc': 'A pilgrim survived the Dead God.',
  'hype_loc': 'Few can stop him.',
  'npe_desc_loc': 'Slashes his foes with mana-draining attacks',
  'facets': facets,
  'str_base': 21,
  'str_gain': 1.6,
  'agi_base': 25,
  'agi_gain': 2.8,
  'int_base': 12,
  'int_gain': 1.8,
  'primary_attr': 1,
  'complexity': 1,
  'attack_capability': 1,
  'role_levels': const [3, 0, 1, 0, 0, 0, 3, 0, 0],
  'damage_min': 54,
  'damage_max': 58,
  'attack_rate': 1.4,
  'attack_range': 150,
  'projectile_speed': 0,
  'armor': 6.166667,
  'magic_resistance': 25,
  'movement_speed': 315,
  'turn_rate': 0.6,
  'sight_range_day': 1800,
  'sight_range_night': 800,
  'max_health': 582,
  'health_regen': 3.6,
  'max_mana': 219,
  'mana_regen': 0.6,
  'abilities': abilities ?? baseAbilities(),
  'talents': talents ?? baseTalents(),
  'facet_abilities': facetAbilities ?? const [],
};

/// Wraps a hero document in the feed's envelope.
Map<String, dynamic> feedDocument(Map<String, Object?> hero) => {
  'result': {
    'status': 1,
    'data': {
      'heroes': [hero],
    },
  },
};
