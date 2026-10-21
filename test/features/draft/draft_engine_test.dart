import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/features/draft/draft_engine.dart';
import 'package:dota2_guide/features/draft/matchup_matrix.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';

void main() {
  group('DraftEngine', () {
    // 5-hero test dataset
    final hero1 = const HeroSummary(
      id: 1,
      valveKey: 'npc_dota_hero_antimage',
      localizedName: 'Anti-Mage',
      primaryAttribute: PrimaryAttribute.agility,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/antimage.png',
    );
    final hero2 = const HeroSummary(
      id: 2,
      valveKey: 'npc_dota_hero_axe',
      localizedName: 'Axe',
      primaryAttribute: PrimaryAttribute.strength,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/axe.png',
    );
    final hero3 = const HeroSummary(
      id: 3,
      valveKey: 'npc_dota_hero_bane',
      localizedName: 'Bane',
      primaryAttribute: PrimaryAttribute.universal,
      complexity: 2,
      portraitUrl: 'https://cdn.example.com/bane.png',
    );
    final hero4 = const HeroSummary(
      id: 4,
      valveKey: 'npc_dota_hero_bloodseeker',
      localizedName: 'Bloodseeker',
      primaryAttribute: PrimaryAttribute.agility,
      complexity: 1,
      portraitUrl: 'https://cdn.example.com/bloodseeker.png',
    );

    // Baseline win rates:
    // Hero 1 (Anti-Mage): (30 + 50) / 200 = 0.40
    // Hero 2 (Axe): (70 + 60) / 200 = 0.65
    // Hero 3 (Bane): (40 + 60) / 200 = 0.50
    // Hero 4 (Bloodseeker): (70 + 30) / 200 = 0.50
    // Hero 5 (Crystal Maiden): 50 / 100 = 0.50
    final matrix = MatchupMatrix.fromJson({
      '1': {
        '2': [30, 100], // 0.30 vs Axe
        '3': [50, 100],
      },
      '2': {
        '1': [70, 100],
        '3': [60, 100],
      },
      '3': {
        '1': [40, 100],
        '2': [60, 100], // 0.60 vs Axe
      },
      '4': {
        '1': [70, 100], // 0.70 vs Anti-Mage
        '2': [30, 100], // 0.30 vs Axe
      },
      '5': {
        '1': [50, 100],
      },
    });

    final fourHeroes = [hero1, hero2, hero3, hero4];

    test('calculates normalized advantage for a single hero vs enemy pair', () {
      // Hero 1 (AM, base 0.40) vs Hero 2 (Axe, base 0.65), AM win rate vs Axe = 0.30:
      // Advantage(1, 2) = (0.30 - 0.40) - (0.65 - 0.50) = -0.10 - 0.15 = -0.25 (-25.0%)
      final adv1vs2 = DraftEngine.computeAdvantage(
        matrix: matrix,
        heroId: 1,
        enemyHeroId: 2,
      );
      expect(adv1vs2, closeTo(-0.25, 0.0001));

      // Hero 3 (Bane, base 0.50) vs Hero 2 (Axe, base 0.65), Bane win rate vs Axe = 0.60:
      // Advantage(3, 2) = (0.60 - 0.50) - (0.65 - 0.50) = 0.10 - 0.15 = -0.05 (-5.0%)
      final adv3vs2 = DraftEngine.computeAdvantage(
        matrix: matrix,
        heroId: 3,
        enemyHeroId: 2,
      );
      expect(adv3vs2, closeTo(-0.05, 0.0001));

      // Hero 4 (Bloodseeker, base 0.50) vs Hero 1 (AM, base 0.40), BS win rate vs AM = 0.70:
      // Advantage(4, 1) = (0.70 - 0.50) - (0.40 - 0.50) = 0.20 - (-0.10) = +0.30 (+30.0%)
      final adv4vs1 = DraftEngine.computeAdvantage(
        matrix: matrix,
        heroId: 4,
        enemyHeroId: 1,
      );
      expect(adv4vs1, closeTo(0.30, 0.0001));
    });

    test('computes arithmetic mean advantage when 0, 1, 2, 3, and 5 enemies are present', () {
      // 0 enemies -> 0.0
      expect(
        DraftEngine.computeAggregateAdvantage(
          matrix: matrix,
          heroId: 4,
          enemyHeroIds: [],
        ),
        0.0,
      );

      // 1 enemy (Hero 1, Anti-Mage) -> +0.30
      expect(
        DraftEngine.computeAggregateAdvantage(
          matrix: matrix,
          heroId: 4,
          enemyHeroIds: [1],
        ),
        closeTo(0.30, 0.0001),
      );

      // 2 enemies (Hero 2: -0.35, Hero 1: +0.30) -> -0.025
      expect(
        DraftEngine.computeAggregateAdvantage(
          matrix: matrix,
          heroId: 4,
          enemyHeroIds: [2, 1],
        ),
        closeTo(-0.025, 0.0001),
      );

      // 3 enemies: Hero 2 (-0.35), Hero 1 (+0.30), Hero 3 (no games -> 0.50 - 0.50 - (0.50 - 0.50) = 0.0)
      // Mean = (-0.35 + 0.30 + 0.0) / 3 = -0.05 / 3 = -0.016666...
      expect(
        DraftEngine.computeAggregateAdvantage(
          matrix: matrix,
          heroId: 4,
          enemyHeroIds: [2, 1, 3],
        ),
        closeTo(-0.05 / 3, 0.0001),
      );

      // 5 enemies: Hero 2 (-0.35), Hero 1 (+0.30), Hero 3 (0.0), Hero 5 (0.0), Hero 2 again (-0.35)
      // Sum = -0.35 + 0.30 + 0.0 + 0.0 - 0.35 = -0.40. Mean = -0.40 / 5 = -0.08
      expect(
        DraftEngine.computeAggregateAdvantage(
          matrix: matrix,
          heroId: 4,
          enemyHeroIds: [2, 1, 3, 5, 2],
        ),
        closeTo(-0.08, 0.0001),
      );
    });

    test('ranks candidate heroes by descending advantage against enemies', () {
      final candidates = DraftEngine.rankCandidates(
        matrix: matrix,
        heroes: fourHeroes,
        enemyHeroIds: [2], // Axe
        alliedHeroIds: [],
      );

      // Against Axe (2):
      // Hero 3 (Bane): -0.05
      // Hero 1 (AM): -0.25
      // Hero 4 (BS): -0.35
      // Axe (2) is enemy pick, so is marked assigned and sorted to bottom
      final unassigned = candidates.where((c) => !c.isAssigned).toList();
      expect(unassigned.map((c) => c.hero.id).toList(), [3, 1, 4]);
      expect(unassigned[0].advantage, closeTo(-0.05, 0.0001));
      expect(unassigned[0].advantagePercentage, '-5.0%');
      expect(unassigned[1].advantage, closeTo(-0.25, 0.0001));
      expect(unassigned[1].advantagePercentage, '-25.0%');
      expect(unassigned[2].advantage, closeTo(-0.35, 0.0001));
      expect(unassigned[2].advantagePercentage, '-35.0%');
    });

    test(
      'marks assigned allied and enemy heroes as assigned and separates them',
      () {
        final candidates = DraftEngine.rankCandidates(
          matrix: matrix,
          heroes: fourHeroes,
          enemyHeroIds: [2],
          alliedHeroIds: [1],
        );

        final hero2Candidate = candidates.firstWhere((c) => c.hero.id == 2);
        final hero1Candidate = candidates.firstWhere((c) => c.hero.id == 1);
        final hero3Candidate = candidates.firstWhere((c) => c.hero.id == 3);

        expect(hero2Candidate.isAssigned, isTrue);
        expect(hero1Candidate.isAssigned, isTrue);
        expect(hero3Candidate.isAssigned, isFalse);

        final unassigned = candidates.where((c) => !c.isAssigned).toList();
        expect(unassigned.map((c) => c.hero.id), containsAllInOrder([3, 4]));
        expect(unassigned.any((c) => c.hero.id == 1), isFalse);
        expect(unassigned.any((c) => c.hero.id == 2), isFalse);
      },
    );

    test(
      'falls back to baseline win rate ranking when no enemies are picked',
      () {
        final candidates = DraftEngine.rankCandidates(
          matrix: matrix,
          heroes: fourHeroes,
          enemyHeroIds: [],
          alliedHeroIds: [],
        );

        // Baselines: Hero 2: 0.65, Hero 3: 0.50, Hero 4: 0.50, Hero 1: 0.40
        // Bane (3) vs Bloodseeker (4): Bane is alphabetically first
        expect(candidates.map((c) => c.hero.id).toList(), [2, 3, 4, 1]);
        expect(candidates[0].hasAdvantage, isFalse);
        expect(candidates[0].baseWinRatePercentage, '65.0%');
        expect(candidates.last.hero.id, 1);
        expect(candidates.last.baseWinRatePercentage, '40.0%');
      },
    );
  });
}
