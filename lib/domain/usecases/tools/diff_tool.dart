/// @file diff_tool.dart
/// @brief Use case for comparing two strings and producing a structured diff.
///
/// Provides a word-level diff between two strings, highlighting additions,
/// removals, and unchanged sections. Useful for comparing API responses,
/// request bodies, or configuration files.
library;

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../usecase.dart';

/// The type of change for a diff segment.
enum DiffType {
  /// Text that exists in both strings (unchanged).
  @JsonValue('unchanged')
  unchanged,

  /// Text that was added (present only in the second string).
  @JsonValue('added')
  added,

  /// Text that was removed (present only in the first string).
  @JsonValue('removed')
  removed,
}

/// A single segment of a diff result.
///
/// Each segment has a [type] indicating whether the text was added,
/// removed, or unchanged, and the [text] content of the segment.
class DiffResult {
  /// The type of change for this segment.
  final DiffType type;

  /// The text content of this segment.
  final String text;

  /// Creates a new [DiffResult].
  const DiffResult({required this.type, required this.text});

  @override
  String toString() => 'DiffResult(type: $type, text: "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffResult &&
          type == other.type &&
          text == other.text;

  @override
  int get hashCode => type.hashCode ^ text.hashCode;
}

/// Parameters for the diff tool use case.
class DiffToolParams {
  /// The original string (the "before" or "left" side).
  final String original;

  /// The modified string (the "after" or "right" side).
  final String modified;

  /// Creates parameter object for the diff tool.
  ///
  /// [original] - The base string to compare against.
  /// [modified] - The string to compare with the original.
  const DiffToolParams({
    required this.original,
    required this.modified,
  });
}

/// Result of the diff operation.
class DiffToolResult {
  /// List of diff segments in order.
  final List<DiffResult> results;

  /// Summary statistics about the diff.
  final DiffStatistics statistics;

  /// Creates a new [DiffToolResult].
  const DiffToolResult({
    required this.results,
    required this.statistics,
  });
}

/// Statistics summarizing the differences between two strings.
class DiffStatistics {
  /// Number of characters that are unchanged.
  final int unchangedCount;

  /// Number of characters that were added.
  final int addedCount;

  /// Number of characters that were removed.
  final int removedCount;

  /// Total number of characters across both strings (may count shared chars twice).
  int get totalChanges => addedCount + removedCount;

  /// Creates a new [DiffStatistics].
  const DiffStatistics({
    required this.unchangedCount,
    required this.addedCount,
    required this.removedCount,
  });

  @override
  String toString() =>
      'DiffStatistics(unchanged: $unchangedCount, added: $addedCount, removed: $removedCount)';
}

/// Compares two strings and produces a structured word-level diff.
///
/// Uses the diff_match_patch algorithm to compute the shortest edit
/// script between the two strings, then converts the result into
/// a list of typed [DiffResult] segments suitable for UI rendering.
///
/// The diff operates at the character/word level and merges adjacent
/// segments of the same type for cleaner output.
class DiffTool extends UseCase<DiffToolResult, DiffToolParams> {
  /// The diff_match_patch instance used for computing diffs.
  final DiffMatchPatch _dmp;

  /// Creates a new [DiffTool] use case.
  ///
  /// [_dmp] - Optional DiffMatchPatch instance for testing. Defaults to a new instance.
  DiffTool([DiffMatchPatch? dmp]) : _dmp = dmp ?? DiffMatchPatch();

  /// Computes the diff between the original and modified strings.
  @override
  Future<DiffToolResult> call(DiffToolParams params) async {
    final diffs = _dmp.diff(params.original, params.modified);

    // Clean up the diff for human readability.
    _dmp.diffCleanupSemantic(diffs);

    // Convert to DiffResult list and compute statistics.
    final results = <DiffResult>[];
    var unchangedCount = 0;
    var addedCount = 0;
    var removedCount = 0;

    for (final diff in diffs) {
      final text = diff.text;
      final type = _mapDiffOperation(diff.operation);

      results.add(DiffResult(type: type, text: text));

      switch (type) {
        case DiffType.unchanged:
          unchangedCount += text.length;
          break;
        case DiffType.added:
          addedCount += text.length;
          break;
        case DiffType.removed:
          removedCount += text.length;
          break;
      }
    }

    final statistics = DiffStatistics(
      unchangedCount: unchangedCount,
      addedCount: addedCount,
      removedCount: removedCount,
    );

    return DiffToolResult(results: results, statistics: statistics);
  }

  /// Maps a diff_match_patch operation constant to our domain [DiffType].
  DiffType _mapDiffOperation(int operation) {
    switch (operation) {
      case 0:
        return DiffType.unchanged;
      case 1:
        return DiffType.added;
      case -1:
        return DiffType.removed;
      default:
        return DiffType.unchanged;
    }
  }
}