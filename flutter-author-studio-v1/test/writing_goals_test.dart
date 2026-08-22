import 'package:author_studio_v1/core/writing_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults', () {
    test('the seeded targets are 2,000 daily, 10,000 weekly, 40,000 monthly',
        () {
      expect(WritingGoals.seedDefaults.dailyWords, 2000);
      expect(WritingGoals.seedDefaults.weeklyWords, 10000);
      expect(WritingGoals.seedDefaults.monthlyWords, 40000);
    });

    test('defaultsFor carries the project id and leaves the targets alone', () {
      final goals = WritingGoals.defaultsFor('project-a');

      expect(goals.projectId, 'project-a');
      expect(goals.dailyWords, WritingGoals.seedDefaults.dailyWords);
      expect(goals.weeklyWords, WritingGoals.seedDefaults.weeklyWords);
      expect(goals.monthlyWords, WritingGoals.seedDefaults.monthlyWords);
    });

    test('an unedited project reports no edit instant', () {
      expect(WritingGoals.defaultsFor('project-a').updatedAt, isNull);
    });

    test('the seeded targets are not customized, and any change is', () {
      expect(WritingGoals.defaultsFor('project-a').isCustomized, isFalse);
      expect(
        WritingGoals.defaultsFor('project-a').copyWith(dailyWords: 1500)
            .isCustomized,
        isTrue,
      );
    });
  });

  group('a goal of zero means no goal', () {
    test('zero targets report themselves absent rather than small', () {
      const goals = WritingGoals(
        projectId: 'project-a',
        dailyWords: 0,
        weeklyWords: 0,
        monthlyWords: 0,
      );

      expect(goals.hasDailyGoal, isFalse);
      expect(goals.hasWeeklyGoal, isFalse);
      expect(goals.hasMonthlyGoal, isFalse);
    });

    test('a set target reports itself present', () {
      final goals = WritingGoals.defaultsFor('project-a');

      expect(goals.hasDailyGoal, isTrue);
      expect(goals.hasWeeklyGoal, isTrue);
      expect(goals.hasMonthlyGoal, isTrue);
    });
  });

  group('normalized', () {
    test('negative targets floor at zero rather than inverting progress', () {
      const goals = WritingGoals(
        projectId: 'project-a',
        dailyWords: -500,
        weeklyWords: -1,
        monthlyWords: -40000,
      );

      final normalized = goals.normalized();

      expect(normalized.dailyWords, 0);
      expect(normalized.weeklyWords, 0);
      expect(normalized.monthlyWords, 0);
    });

    test('absurd targets cap at the maximum', () {
      const goals = WritingGoals(
        projectId: 'project-a',
        dailyWords: 50000000,
        weeklyWords: WritingGoals.maximumWords + 1,
        monthlyWords: WritingGoals.maximumWords,
      );

      final normalized = goals.normalized();

      expect(normalized.dailyWords, WritingGoals.maximumWords);
      expect(normalized.weeklyWords, WritingGoals.maximumWords);
      expect(normalized.monthlyWords, WritingGoals.maximumWords);
    });

    test('workable targets pass through untouched', () {
      final goals = WritingGoals.defaultsFor('project-a');

      expect(goals.normalized(), goals);
    });

    test('normalizing preserves the project and the edit instant', () {
      final edited = DateTime(2026, 8, 20, 9, 15);
      final goals = WritingGoals(
        projectId: 'project-a',
        dailyWords: -1,
        weeklyWords: 10000,
        monthlyWords: 40000,
        updatedAt: edited,
      ).normalized();

      expect(goals.projectId, 'project-a');
      expect(goals.updatedAt, edited);
    });
  });

  group('serialization', () {
    test('round-trips every target and the edit instant', () {
      final goals = WritingGoals(
        projectId: 'project-a',
        dailyWords: 1500,
        weeklyWords: 9000,
        monthlyWords: 30000,
        updatedAt: DateTime(2026, 8, 20, 9, 15),
      );

      final restored = WritingGoals.fromJson(
        Map<String, dynamic>.from(goals.toJson()),
      );

      expect(restored, goals);
    });

    test('round-trips a never-edited goal set', () {
      final goals = WritingGoals.defaultsFor('project-a');

      final restored = WritingGoals.fromJson(
        Map<String, dynamic>.from(goals.toJson()),
      );

      expect(restored, goals);
      expect(restored.updatedAt, isNull);
    });

    test('an absent target falls back to the seeded default', () {
      final restored = WritingGoals.fromJson({'projectId': 'project-a'});

      expect(restored.dailyWords, WritingGoals.seedDefaults.dailyWords);
      expect(restored.weeklyWords, WritingGoals.seedDefaults.weeklyWords);
      expect(restored.monthlyWords, WritingGoals.seedDefaults.monthlyWords);
    });

    test('the edit instant survives as the same moment', () {
      final edited = DateTime(2026, 8, 20, 23, 40);
      final restored = WritingGoals.fromJson(
        Map<String, dynamic>.from(
          WritingGoals.defaultsFor('project-a')
              .copyWith(updatedAt: edited)
              .toJson(),
        ),
      );

      expect(restored.updatedAt?.isAtSameMomentAs(edited), isTrue);
    });
  });

  group('value semantics', () {
    test('two goal sets with the same targets are equal', () {
      expect(
        WritingGoals.defaultsFor('project-a'),
        WritingGoals.defaultsFor('project-a'),
      );
      expect(
        WritingGoals.defaultsFor('project-a').hashCode,
        WritingGoals.defaultsFor('project-a').hashCode,
      );
    });

    test('goals for different projects are not equal', () {
      expect(
        WritingGoals.defaultsFor('project-a'),
        isNot(WritingGoals.defaultsFor('project-b')),
      );
    });

    test('copyWith changes one target and leaves the rest', () {
      final goals = WritingGoals.defaultsFor('project-a')
          .copyWith(dailyWords: 1500);

      expect(goals.dailyWords, 1500);
      expect(goals.weeklyWords, WritingGoals.seedDefaults.weeklyWords);
      expect(goals.monthlyWords, WritingGoals.seedDefaults.monthlyWords);
      expect(goals.projectId, 'project-a');
    });
  });
}
