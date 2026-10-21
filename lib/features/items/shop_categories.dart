// Shop categories (spec: "browse Items grouped by shop category, so that I
// can find Items the way the in-game shop presents them").
//
// Pure Dart on purpose: the snapshot tool (`tool/snapshot.dart`) and the
// refresh unit (`items_snapshot_unit.dart`) both classify items while
// converting feeds, and `dart run` cannot compile anything reaching `dart:ui`.
//
// PROVENANCE — read before editing.
//
// Valve's `itemlist` feed carries NO shop category (verified live 2026-10-21;
// the `shop_tags` field an older research note claims is gone — `language=en`
// is rejected outright). The in-game shop's tabs are client data, so the only
// way to group "the way the shop presents them" is a hand-curated table.
//
// This table is therefore AUTHORED CONTENT, not snapshot data: it maps a
// Valve item key to the shop tab that item sat in when it was written (patch
// 7.41f era). It is deliberately not exhaustive:
//
//   * neutral Items are classified from the feed's `neutral_item_tier`
//     (authoritative, no curation needed);
//   * `item_recipe_*` entries are classified by prefix (they are recipe
//     prices, not shop rows);
//   * everything else unmapped lands in [ShopCategory.other] — retired
//     neutral Items, event items, River Vials, and anything Valve ships
//     after this table was written.
//
// `dart run tool/snapshot.dart` prints every key that fell into `other`, so a
// newly shipped shop Item is visible to the maintainer at snapshot time
// instead of silently hiding in a catch-all section.

/// The shop tab an Item is presented under.
enum ShopCategory {
  consumables,
  attributes,
  armaments,
  arcane,
  common,
  support,
  caster,
  weapons,
  armor,
  artifacts,
  neutral,
  other;

  /// Wire name stored in the snapshot files (the enum's Dart name, same
  /// convention as [PrimaryAttribute]).
  String get wireName => name;

  /// Section heading in the Items tab. `neutral` and `other` read as their
  /// in-game counterparts rather than as shop tabs.
  String get label => switch (this) {
    consumables => 'Consumables',
    attributes => 'Attributes',
    armaments => 'Armaments',
    arcane => 'Arcane',
    common => 'Common',
    support => 'Support',
    caster => 'Caster',
    weapons => 'Weapons',
    armor => 'Armor',
    artifacts => 'Artifacts',
    neutral => 'Neutral Items',
    other => 'Miscellaneous',
  };

  static ShopCategory parse(String wireName) => values.firstWhere(
    (c) => c.wireName == wireName,
    orElse: () => throw FormatException('Unknown shop category "$wireName"'),
  );
}

/// Valve item key prefix for a recipe price entry (the feed's own naming:
/// `item_recipe_magic_wand` pairs with `item_magic_wand`; every one of the
/// 129 recipe entries in the live feed has its matching base Item).
const String itemRecipeKeyPrefix = 'item_recipe_';

/// Whether [valveKey] names a recipe entry rather than an Item you can hold.
bool isRecipeItemKey(String valveKey) =>
    valveKey.startsWith(itemRecipeKeyPrefix);

/// The neutral-tier feed value that means "not a neutral Item" (the feed
/// serves `4294967295`, i.e. -1 as an unsigned 32-bit int).
const int nonNeutralTier = -1;

/// The shop tab for the Item with [valveKey] and feed [neutralTier].
///
/// Neutral Items are classified from the feed (tier ≥ 0); everything else
/// comes from [curatedShopCategories], falling back to
/// [ShopCategory.other] so an unmapped or newly shipped Item still renders.
ShopCategory shopCategoryFor({
  required String valveKey,
  required int neutralTier,
}) {
  // The feed marks non-neutral Items with `nonNeutralTier` (-1); every real
  // tier is >= 0.
  if (neutralTier >= 0) return ShopCategory.neutral;
  return curatedShopCategories[valveKey] ?? ShopCategory.other;
}

/// In-game neutral tiers are labelled 1-based; the feed stores them 0-based
/// (`0` … `4` for the current five-tier drop pool, verified live 2026-10-21).
int neutralTierLabel(int feedTier) => feedTier + 1;

/// The curated shop-tab table (see the file header before editing).
///
/// Keys are Valve item keys exactly as the feed serves them, so a typo
/// quietly drops the Item into `Miscellaneous` — the snapshot tool's `other`
/// report is the safety net.
const Map<String, ShopCategory> curatedShopCategories = {
  // --- Consumables --------------------------------------------------------
  'item_tango': ShopCategory.consumables,
  'item_tango_single': ShopCategory.consumables,
  'item_clarity': ShopCategory.consumables,
  'item_flask': ShopCategory.consumables,
  'item_faerie_fire': ShopCategory.consumables,
  'item_dust': ShopCategory.consumables,
  'item_smoke_of_deceit': ShopCategory.consumables,
  'item_tpscroll': ShopCategory.consumables,
  'item_ward_observer': ShopCategory.consumables,
  'item_ward_sentry': ShopCategory.consumables,
  'item_ward_dispenser': ShopCategory.consumables,
  'item_blood_grenade': ShopCategory.consumables,
  'item_enchanted_mango': ShopCategory.consumables,
  'item_bottle': ShopCategory.consumables,
  'item_courier': ShopCategory.consumables,
  'item_flying_courier': ShopCategory.consumables,
  'item_gem': ShopCategory.consumables,
  'item_quelling_blade': ShopCategory.consumables,
  'item_iron_talon': ShopCategory.consumables,
  'item_mango_tree': ShopCategory.consumables,
  'item_tome_of_knowledge': ShopCategory.consumables,
  'item_tome_of_aghanim': ShopCategory.consumables,

  // --- Attributes (the stat components) ----------------------------------
  'item_gauntlets': ShopCategory.attributes,
  'item_slippers': ShopCategory.attributes,
  'item_mantle': ShopCategory.attributes,
  'item_circlet': ShopCategory.attributes,
  'item_belt_of_strength': ShopCategory.attributes,
  'item_boots_of_elves': ShopCategory.attributes,
  'item_robe': ShopCategory.attributes,
  'item_ogre_axe': ShopCategory.attributes,
  'item_blade_of_alacrity': ShopCategory.attributes,
  'item_staff_of_wizardry': ShopCategory.attributes,
  'item_ring_of_protection': ShopCategory.attributes,
  'item_branches': ShopCategory.attributes,
  'item_stout_shield': ShopCategory.attributes,

  // --- Armaments (the damage/armor components) ---------------------------
  'item_blades_of_attack': ShopCategory.armaments,
  'item_broadsword': ShopCategory.armaments,
  'item_chainmail': ShopCategory.armaments,
  'item_helm_of_iron_will': ShopCategory.armaments,
  'item_claymore': ShopCategory.armaments,
  'item_quarterstaff': ShopCategory.armaments,
  'item_mithril_hammer': ShopCategory.armaments,
  'item_platemail': ShopCategory.armaments,
  'item_hyperstone': ShopCategory.armaments,
  'item_relic': ShopCategory.armaments,
  'item_demon_edge': ShopCategory.armaments,
  'item_javelin': ShopCategory.armaments,
  'item_gloves': ShopCategory.armaments,
  'item_cloak': ShopCategory.armaments,
  'item_talisman_of_evasion': ShopCategory.armaments,

  // --- Arcane (regen components, boosters, boots) ------------------------
  'item_boots': ShopCategory.arcane,
  'item_ring_of_regen': ShopCategory.arcane,
  'item_sobi_mask': ShopCategory.arcane,
  'item_void_stone': ShopCategory.arcane,
  'item_ring_of_health': ShopCategory.arcane,
  'item_wind_lace': ShopCategory.arcane,
  'item_energy_booster': ShopCategory.arcane,
  'item_point_booster': ShopCategory.arcane,
  'item_vitality_booster': ShopCategory.arcane,
  'item_ultimate_orb': ShopCategory.arcane,
  'item_pers': ShopCategory.arcane,
  'item_power_treads': ShopCategory.arcane,
  'item_phase_boots': ShopCategory.arcane,
  'item_arcane_boots': ShopCategory.arcane,
  'item_tranquil_boots': ShopCategory.arcane,
  'item_travel_boots': ShopCategory.arcane,
  'item_travel_boots_2': ShopCategory.arcane,
  'item_boots_of_bearing': ShopCategory.arcane,

  // --- Common (the cheap combined staples) -------------------------------
  'item_magic_stick': ShopCategory.common,
  'item_magic_wand': ShopCategory.common,
  'item_bracer': ShopCategory.common,
  'item_wraith_band': ShopCategory.common,
  'item_null_talisman': ShopCategory.common,
  'item_soul_ring': ShopCategory.common,
  'item_falcon_blade': ShopCategory.common,
  'item_ring_of_basilius': ShopCategory.common,
  'item_ring_of_aquila': ShopCategory.common,
  'item_headdress': ShopCategory.common,
  'item_buckler': ShopCategory.common,
  'item_ancient_janggo': ShopCategory.common,
  'item_hand_of_midas': ShopCategory.common,
  'item_aeon_disk': ShopCategory.common,
  'item_poor_mans_shield': ShopCategory.common,

  // --- Support ------------------------------------------------------------
  'item_mekansm': ShopCategory.support,
  'item_pipe': ShopCategory.support,
  'item_glimmer_cape': ShopCategory.support,
  'item_solar_crest': ShopCategory.support,
  'item_holy_locket': ShopCategory.support,
  'item_vladmir': ShopCategory.support,
  'item_urn_of_shadows': ShopCategory.support,
  'item_spirit_vessel': ShopCategory.support,
  'item_guardian_greaves': ShopCategory.support,
  'item_pavise': ShopCategory.support,
  'item_medallion_of_courage': ShopCategory.support,
  'item_wraith_pact': ShopCategory.support,

  // --- Caster -------------------------------------------------------------
  'item_blink': ShopCategory.caster,
  'item_arcane_blink': ShopCategory.caster,
  'item_swift_blink': ShopCategory.caster,
  'item_overwhelming_blink': ShopCategory.caster,
  'item_aether_lens': ShopCategory.caster,
  'item_cyclone': ShopCategory.caster,
  'item_ghost': ShopCategory.caster,
  'item_veil_of_discord': ShopCategory.caster,
  'item_rod_of_atos': ShopCategory.caster,
  'item_orchid': ShopCategory.caster,
  'item_meteor_hammer': ShopCategory.caster,
  'item_force_staff': ShopCategory.caster,
  'item_necronomicon': ShopCategory.caster,
  'item_necronomicon_2': ShopCategory.caster,
  'item_necronomicon_3': ShopCategory.caster,
  'item_witch_blade': ShopCategory.caster,
  'item_phylactery': ShopCategory.caster,

  // --- Weapons ------------------------------------------------------------
  'item_lesser_crit': ShopCategory.weapons,
  'item_desolator': ShopCategory.weapons,
  'item_maelstrom': ShopCategory.weapons,
  'item_mjollnir': ShopCategory.weapons,
  'item_gungir': ShopCategory.weapons,
  'item_basher': ShopCategory.weapons,
  'item_mask_of_madness': ShopCategory.weapons,
  'item_helm_of_the_dominator': ShopCategory.weapons,
  'item_helm_of_the_overlord': ShopCategory.weapons,
  'item_echo_sabre': ShopCategory.weapons,
  'item_diffusal_blade': ShopCategory.weapons,
  'item_disperser': ShopCategory.weapons,
  'item_bfury': ShopCategory.weapons,
  'item_armlet': ShopCategory.weapons,
  'item_manta': ShopCategory.weapons,
  'item_silver_edge': ShopCategory.weapons,
  'item_mage_slayer': ShopCategory.weapons,
  'item_revenants_brooch': ShopCategory.weapons,
  'item_harpoon': ShopCategory.weapons,
  'item_hurricane_pike': ShopCategory.weapons,
  'item_sange': ShopCategory.weapons,
  'item_yasha': ShopCategory.weapons,
  'item_kaya': ShopCategory.weapons,
  'item_sange_and_yasha': ShopCategory.weapons,
  'item_yasha_and_kaya': ShopCategory.weapons,
  'item_kaya_and_sange': ShopCategory.weapons,
  'item_trident': ShopCategory.weapons,
  'item_orb_of_corrosion': ShopCategory.weapons,

  // --- Armor --------------------------------------------------------------
  'item_vanguard': ShopCategory.armor,
  'item_hood_of_defiance': ShopCategory.armor,
  'item_blade_mail': ShopCategory.armor,
  'item_crimson_guard': ShopCategory.armor,
  'item_eternal_shroud': ShopCategory.armor,
  'item_assault': ShopCategory.armor,
  'item_shivas_guard': ShopCategory.armor,

  // --- Artifacts ----------------------------------------------------------
  'item_greater_crit': ShopCategory.artifacts,
  'item_monkey_king_bar': ShopCategory.artifacts,
  'item_skadi': ShopCategory.artifacts,
  'item_satanic': ShopCategory.artifacts,
  'item_radiance': ShopCategory.artifacts,
  'item_butterfly': ShopCategory.artifacts,
  'item_bloodthorn': ShopCategory.artifacts,
  'item_abyssal_blade': ShopCategory.artifacts,
  'item_sphere': ShopCategory.artifacts,
  'item_heart': ShopCategory.artifacts,
  'item_bloodstone': ShopCategory.artifacts,
  'item_octarine_core': ShopCategory.artifacts,
  'item_refresher': ShopCategory.artifacts,
  'item_nullifier': ShopCategory.artifacts,
  'item_sheepstick': ShopCategory.artifacts,
  'item_ethereal_blade': ShopCategory.artifacts,
  'item_rapier': ShopCategory.artifacts,
  'item_black_king_bar': ShopCategory.artifacts,
  'item_ultimate_scepter': ShopCategory.artifacts,
  'item_ultimate_scepter_2': ShopCategory.artifacts,
  'item_aghanims_shard': ShopCategory.artifacts,
  'item_heavens_halberd': ShopCategory.artifacts,
  'item_khanda': ShopCategory.artifacts,
  'item_devastator': ShopCategory.artifacts,
};
