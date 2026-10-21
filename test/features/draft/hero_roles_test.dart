import 'package:dota2_guide/features/draft/draft_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeroRoleLevels', () {
    test('parses official 9-element role levels list', () {
      // Axe: Carry: 1, Support: 0, Nuker: 0, Disabler: 2, Jungler: 0, Durable: 3, Escape: 0, Pusher: 0, Initiator: 3
      final axeRoles = HeroRoleLevels.fromList(const [
        1,
        0,
        0,
        2,
        0,
        3,
        0,
        0,
        3,
      ]);

      expect(axeRoles.carry, 1);
      expect(axeRoles.support, 0);
      expect(axeRoles.nuker, 0);
      expect(axeRoles.disabler, 2);
      expect(axeRoles.jungler, 0);
      expect(axeRoles.durable, 3);
      expect(axeRoles.escape, 0);
      expect(axeRoles.pusher, 0);
      expect(axeRoles.initiator, 3);
    });

    test('classifies competitive positions correctly', () {
      // Anti-Mage: [3, 0, 1, 0, 0, 0, 3, 0, 0] -> Pos 1 (Carry 3)
      final antiMage = HeroRoleLevels.fromList(const [
        3,
        0,
        1,
        0,
        0,
        0,
        3,
        0,
        0,
      ]);
      expect(antiMage.isSuitableForPosition(DraftPosition.pos1), isTrue);
      expect(antiMage.isSuitableForPosition(DraftPosition.pos5), isFalse);

      // Queen of Pain: [1, 0, 3, 0, 0, 0, 3, 0, 0] -> Pos 2 (Nuker 3, Escape 3)
      final qop = HeroRoleLevels.fromList(const [1, 0, 3, 0, 0, 0, 3, 0, 0]);
      expect(qop.isSuitableForPosition(DraftPosition.pos2), isTrue);

      // Axe: [1, 0, 0, 2, 0, 3, 0, 0, 3] -> Pos 3 (Durable 3, Initiator 3)
      final axe = HeroRoleLevels.fromList(const [1, 0, 0, 2, 0, 3, 0, 0, 3]);
      expect(axe.isSuitableForPosition(DraftPosition.pos3), isTrue);

      // Earthshaker: [0, 1, 1, 2, 0, 0, 0, 0, 3] -> Pos 4 (Support 1, Initiator 3, Disabler 2)
      final es = HeroRoleLevels.fromList(const [0, 1, 1, 2, 0, 0, 0, 0, 3]);
      expect(es.isSuitableForPosition(DraftPosition.pos4), isTrue);

      // Crystal Maiden: [0, 3, 2, 2, 0, 0, 0, 0, 0] -> Pos 5 (Support 3)
      final cm = HeroRoleLevels.fromList(const [0, 3, 2, 2, 0, 0, 0, 0, 0]);
      expect(cm.isSuitableForPosition(DraftPosition.pos5), isTrue);
    });
  });

  group('CompositionDiagnostics evaluation', () {
    test('reports missing alerts when allied slots are empty', () {
      final diagnostics = DraftEngine.evaluateComposition(const []);

      expect(diagnostics.disablerPoints, 0);
      expect(diagnostics.durablePoints, 0);
      expect(diagnostics.initiatorPoints, 0);
      expect(diagnostics.supportPoints, 0);

      expect(diagnostics.hasDisabler, isFalse);
      expect(diagnostics.hasDurable, isFalse);
      expect(diagnostics.hasInitiator, isFalse);
      expect(diagnostics.hasSupport, isFalse);
      expect(diagnostics.isBalanced, isFalse);

      expect(
        diagnostics.alerts,
        contains('Draft lacks reliable stuns/disable'),
      );
      expect(diagnostics.alerts, contains('Draft lacks durable frontline'));
      expect(diagnostics.alerts, contains('Draft lacks initiation'));
      expect(diagnostics.alerts, contains('Draft lacks sufficient support'));
    });

    test('dynamically resolves alerts as roles meet thresholds', () {
      // Adding Bane: [0, 2, 1, 3, 0, 1, 0, 0, 0] -> Disabler: 3, Support: 2, Durable: 1
      final bane = HeroRoleLevels.fromList(const [0, 2, 1, 3, 0, 1, 0, 0, 0]);
      var diagnostics = DraftEngine.evaluateComposition([bane]);

      expect(diagnostics.disablerPoints, 3);
      expect(diagnostics.hasDisabler, isTrue);
      expect(
        diagnostics.alerts,
        isNot(contains('Draft lacks reliable stuns/disable')),
      );
      expect(diagnostics.alerts, contains('Draft lacks durable frontline'));
      expect(diagnostics.alerts, contains('Draft lacks initiation'));
      expect(
        diagnostics.alerts,
        contains('Draft lacks sufficient support'),
      ); // Support is 2 < 3

      // Adding Axe: [1, 0, 0, 2, 0, 3, 0, 0, 3] -> Durable: 3, Initiator: 3
      final axe = HeroRoleLevels.fromList(const [1, 0, 0, 2, 0, 3, 0, 0, 3]);
      diagnostics = DraftEngine.evaluateComposition([bane, axe]);

      expect(diagnostics.durablePoints, 4); // 1 + 3 >= 3
      expect(diagnostics.initiatorPoints, 3); // 3 >= 2
      expect(diagnostics.hasDurable, isTrue);
      expect(diagnostics.hasInitiator, isTrue);
      expect(
        diagnostics.alerts,
        isNot(contains('Draft lacks durable frontline')),
      );
      expect(diagnostics.alerts, isNot(contains('Draft lacks initiation')));
      expect(
        diagnostics.alerts,
        contains('Draft lacks sufficient support'),
      ); // still needs 1 more support point

      // Adding Crystal Maiden: [0, 3, 2, 2, 0, 0, 0, 0, 0] -> Support: 3
      final cm = HeroRoleLevels.fromList(const [0, 3, 2, 2, 0, 0, 0, 0, 0]);
      diagnostics = DraftEngine.evaluateComposition([bane, axe, cm]);

      expect(diagnostics.supportPoints, 5); // 2 + 3 >= 3
      expect(diagnostics.hasSupport, isTrue);
      expect(diagnostics.alerts, isEmpty);
      expect(diagnostics.isBalanced, isTrue);
    });
  });
}
