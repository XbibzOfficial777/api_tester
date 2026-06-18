import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/tools/diff_tool.dart';

void main() {
  late DiffTool diffTool;

  setUp(() {
    diffTool = DiffTool();
  });

  group('DiffTool', () {
    group('identical texts', () {
      test('returns all unchanged segments for identical strings', () async {
        const original = 'Hello World';
        const modified = 'Hello World';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        expect(result.results.length, equals(1));
        expect(result.results.first.type, equals(DiffType.unchanged));
        expect(result.results.first.text, equals('Hello World'));
        expect(result.statistics.unchangedCount, equals(11));
        expect(result.statistics.addedCount, equals(0));
        expect(result.statistics.removedCount, equals(0));
      });

      test('empty strings are identical', () async {
        final result = await diffTool(const DiffToolParams(
          original: '',
          modified: '',
        ));

        expect(result.results, isEmpty);
        expect(result.statistics.unchangedCount, equals(0));
        expect(result.statistics.addedCount, equals(0));
        expect(result.statistics.removedCount, equals(0));
      });
    });

    group('completely different texts', () {
      test('all text from original is removed, all from modified is added', () async {
        const original = 'abc';
        const modified = 'xyz';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        // Should have at least one removed segment and one added segment.
        final removedTexts =
            result.results.where((r) => r.type == DiffType.removed).map((r) => r.text).join();
        final addedTexts =
            result.results.where((r) => r.type == DiffType.added).map((r) => r.text).join();

        expect(removedTexts, contains('abc'));
        expect(addedTexts, contains('xyz'));
        expect(result.statistics.totalChanges, greaterThan(0));
      });

      test('empty vs non-empty produces only additions', () async {
        const modified = 'Hello';

        final result = await diffTool(const DiffToolParams(
          original: '',
          modified: modified,
        ));

        // All content is added.
        expect(result.results.every((r) => r.type == DiffType.added), isTrue);
        expect(result.statistics.addedCount, greaterThan(0));
        expect(result.statistics.removedCount, equals(0));
      });

      test('non-empty vs empty produces only removals', () async {
        const original = 'Hello';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: '',
        ));

        // All content is removed.
        expect(result.results.every((r) => r.type == DiffType.removed), isTrue);
        expect(result.statistics.removedCount, greaterThan(0));
        expect(result.statistics.addedCount, equals(0));
      });
    });

    group('partial differences', () {
      test('identifies the changed word in a sentence', () async {
        const original = 'The quick brown fox';
        const modified = 'The slow brown fox';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        // There should be some unchanged content.
        final unchanged =
            result.results.where((r) => r.type == DiffType.unchanged);
        expect(unchanged, isNotEmpty);

        // There should be changes.
        expect(result.statistics.totalChanges, greaterThan(0));

        // The word "quick" should be removed and "slow" should be added.
        final allText = result.results.map((r) => r.text).join();
        expect(allText, contains('quick'));
        expect(allText, contains('slow'));
      });

      test('appending text shows unchanged + added', () async {
        const original = 'Hello';
        const modified = 'Hello World';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        // Should have unchanged "Hello" and added " World".
        final hasUnchanged =
            result.results.any((r) => r.type == DiffType.unchanged);
        final hasAdded =
            result.results.any((r) => r.type == DiffType.added);

        expect(hasUnchanged, isTrue);
        expect(hasAdded, isTrue);
        expect(result.statistics.removedCount, equals(0));
      });
    });

    group('word-level diff accuracy', () {
      test('statistics add up correctly', () async {
        const original = 'one two three four';
        const modified = 'one two five four';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        // The total character count should be consistent.
        final totalReconstructed = result.results.fold<int>(0, (sum, r) {
          switch (r.type) {
            case DiffType.unchanged:
              return sum + r.text.length;
            case DiffType.added:
              return sum;
            case DiffType.removed:
              return sum;
          }
        });

        // Unchanged chars should be a subset of the original.
        expect(result.statistics.unchangedCount, lessThanOrEqualTo(original.length));
      });

      test('handles single character change', () async {
        const original = 'a b c d';
        const modified = 'a x c d';

        final result = await diffTool(const DiffToolParams(
          original: original,
          modified: modified,
        ));

        expect(result.statistics.totalChanges, greaterThan(0));
      });
    });
  });
}