/// @file diff_tool_screen.dart
/// @brief Standalone tool screen for diffing two API responses or JSON bodies.
///
/// Provides two large text input areas (side-by-side on wide screens,
/// stacked on phones), a swap button, load-from-file buttons, a compare
/// button, colour-coded diff results, and a statistics panel.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/tools/diff_tool.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the diff tool screen.
class _DiffScreenState {
  /// Whether a comparison is in progress.
  final bool isComparing;

  /// The diff result, or null if not yet compared.
  final DiffToolResult? diffResult;

  /// Error message.
  final String? error;

  const _DiffScreenState({
    this.isComparing = false,
    this.diffResult,
    this.error,
  });

  _DiffScreenState copyWith({
    bool? isComparing,
    DiffToolResult? diffResult,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return _DiffScreenState(
      isComparing: isComparing ?? this.isComparing,
      diffResult: clearResult ? null : (diffResult ?? this.diffResult),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _DiffScreenNotifier extends StateNotifier<_DiffScreenState> {
  _DiffScreenNotifier() : super(const _DiffScreenState());

  /// Compares two strings and produces a diff result.
  Future<void> compare(String left, String right) async {
    if (left.isEmpty && right.isEmpty) {
      state = state.copyWith(error: 'Both inputs are empty.');
      return;
    }

    state = state.copyWith(
      isComparing: true,
      clearResult: true,
      clearError: true,
    );

    try {
      final tool = DiffTool();
      final result = await tool(DiffToolParams(
        original: left,
        modified: right,
      ));
      state = state.copyWith(isComparing: false, diffResult: result);
    } catch (e) {
      state = state.copyWith(
        isComparing: false,
        error: 'Diff failed: $e',
      );
    }
  }

  /// Resets the diff state.
  void reset() {
    state = const _DiffScreenState();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _diffScreenProvider =
    StateNotifierProvider<_DiffScreenNotifier, _DiffScreenState>(
  (ref) => _DiffScreenNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Side-by-side comparison of two JSON/text payloads with highlighted diffs.
///
/// Features:
/// - Two large text input areas.
/// - Swap button to exchange left and right.
/// - Load from file buttons.
/// - Compare button.
/// - Colour-coded diff results (green = added, red = removed).
/// - Statistics panel showing additions, deletions, unchanged count.
class DiffToolScreen extends ConsumerStatefulWidget {
  /// Creates a [DiffToolScreen].
  const DiffToolScreen({super.key});

  @override
  ConsumerState<DiffToolScreen> createState() => _DiffToolScreenState();
}

class _DiffToolScreenState extends ConsumerState<DiffToolScreen> {
  final _leftController = TextEditingController();
  final _rightController = TextEditingController();

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  /// Swaps the contents of the two text areas.
  void _swap() {
    final temp = _leftController.text;
    _leftController.text = _rightController.text;
    _rightController.text = temp;
  }

  /// Loads a file's content into the left or right controller.
  Future<void> _loadFile(bool isLeft) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final content =
            await String.fromCharCodes(await result.files.single.readAsBytes());
        setState(() {
          if (isLeft) {
            _leftController.text = content;
          } else {
            _rightController.text = content;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  /// Runs the comparison.
  void _compare() {
    ref.read(_diffScreenProvider.notifier).compare(
          _leftController.text,
          _rightController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final diffState = ref.watch(_diffScreenProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diff Tool'),
        actions: [
          if (diffState.diffResult != null)
            IconButton(
              icon: const Icon(Symbols.clear_all, size: 20),
              tooltip: 'Reset',
              onPressed: () {
                ref.read(_diffScreenProvider.notifier).reset();
                _leftController.clear();
                _rightController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // --- Text Inputs ---
          Expanded(
            flex: diffState.diffResult != null ? 1 : 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left panel.
                        Expanded(
                          child: _buildTextArea(
                            controller: _leftController,
                            label: 'Original (Left)',
                            icon: Symbols.format_align_left,
                            hint: 'Paste the original text here…',
                            onLoadFile: () => _loadFile(true),
                            colorScheme: colorScheme,
                          ),
                        ),
                        // Swap button (vertical).
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Symbols.swap_horiz, size: 20),
                                tooltip: 'Swap',
                                onPressed: _swap,
                              ),
                            ],
                          ),
                        ),
                        // Right panel.
                        Expanded(
                          child: _buildTextArea(
                            controller: _rightController,
                            label: 'Modified (Right)',
                            icon: Symbols.format_align_right,
                            hint: 'Paste the modified text here…',
                            onLoadFile: () => _loadFile(false),
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    // Narrow: stacked layout with swap button between.
                    _buildTextArea(
                      controller: _leftController,
                      label: 'Original (Left)',
                      icon: Symbols.format_align_left,
                      hint: 'Paste the original text here…',
                      onLoadFile: () => _loadFile(true),
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: IconButton.filledTonal(
                        icon: const Icon(Symbols.swap_vert, size: 20),
                        tooltip: 'Swap',
                        onPressed: _swap,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextArea(
                      controller: _rightController,
                      label: 'Modified (Right)',
                      icon: Symbols.format_align_right,
                      hint: 'Paste the modified text here…',
                      onLoadFile: () => _loadFile(false),
                      colorScheme: colorScheme,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // --- Compare Button ---
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: diffState.isComparing ? null : _compare,
                      icon: diffState.isComparing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Symbols.compare_arrows, size: 18),
                      label: Text(diffState.isComparing
                          ? 'Comparing…'
                          : 'Compare'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Error ---
          if (diffState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Symbols.error, color: colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(diffState.error!,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error)),
                  ),
                ],
              ),
            ),

          // --- Statistics Panel ---
          if (diffState.diffResult != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(
                    icon: Symbols.add_circle,
                    label: 'Added',
                    count: diffState.diffResult!.statistics.addedCount,
                    color: AppTheme.status2xx,
                  ),
                  _StatItem(
                    icon: Symbols.remove_circle,
                    label: 'Removed',
                    count: diffState.diffResult!.statistics.removedCount,
                    color: AppTheme.status5xx,
                  ),
                  _StatItem(
                    icon: Symbols.remove,
                    label: 'Unchanged',
                    count: diffState.diffResult!.statistics.unchangedCount,
                    color: colorScheme.outline,
                  ),
                ],
              ),
            ),

            // --- Diff Content ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: diffState.diffResult!.results.length,
                itemBuilder: (context, index) {
                  final segment = diffState.diffResult!.results[index];
                  return _buildDiffSegment(segment, colorScheme);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a text area with label and load-from-file button.
  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required VoidCallback onLoadFile,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            // Load from file.
            IconButton(
              icon: const Icon(Symbols.folder_open, size: 16),
              tooltip: 'Load from file',
              onPressed: onLoadFile,
              visualDensity: VisualDensity.compact,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    );
  }

  /// Renders a diff segment with colour coding.
  Widget _buildDiffSegment(DiffResult segment, ColorScheme colorScheme) {
    Color? bgColor;
    if (segment.type == DiffType.added) {
      bgColor = AppTheme.status2xx.withOpacity(0.15);
    } else if (segment.type == DiffType.removed) {
      bgColor = AppTheme.status5xx.withOpacity(0.15);
    }

    final lines = segment.text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          color: bgColor,
          child: Text(
            line.isEmpty ? ' ' : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: segment.type == DiffType.unchanged
                  ? colorScheme.onSurface
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A compact statistic item for the diff results panel.
class _StatItem extends StatelessWidget {
  /// Icon for the stat.
  final IconData icon;

  /// Label (e.g. "Added").
  final String label;

  /// The count.
  final int count;

  /// The colour for the icon and count.
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}