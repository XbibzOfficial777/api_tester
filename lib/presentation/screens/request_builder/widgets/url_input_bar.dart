/// @file url_input_bar.dart
/// @brief The top URL input bar with HTTP method selector, URL text field
///        (with autocomplete), and a send button.
///
/// This is the primary action bar of the request builder. On tablet and
/// landscape orientations it stretches to the full available width.
/// Pressing Enter in the URL field triggers the send action.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/widgets/common/method_chip.dart';

/// The URL input bar widget containing the method selector, URL field,
/// and send button.
///
/// Layout: `[MethodChips (horizontal scroll) | URL TextField | Send]`
class UrlInputBar extends ConsumerStatefulWidget {
  /// Optional callback invoked when the user taps the Send button or presses
  /// Enter. If omitted, the provider-based [sendRequestProvider] is used.
  final VoidCallback? onSend;

  /// Creates a [UrlInputBar].
  const UrlInputBar({super.key, this.onSend});

  @override
  ConsumerState<UrlInputBar> createState() => _UrlInputBarState();
}

class _UrlInputBarState extends ConsumerState<UrlInputBar> {
  late final TextEditingController _urlController;
  late final FocusNode _urlFocus;

  /// Locally cached recent endpoints so autocomplete works while the
  /// async provider is loading.
  List<String> _recentEndpoints = [];

  /// Colour mapping for each HTTP method (mirrors MethodChip logic).
  static const _methodColors = <HttpMethod, Color>{
    HttpMethod.get: Color(0xFF43A047),
    HttpMethod.post: Color(0xFF1E88E5),
    HttpMethod.put: Color(0xFFFB8C00),
    HttpMethod.patch: Color(0xFF00897B),
    HttpMethod.delete: Color(0xFFE53935),
    HttpMethod.head: Color(0xFF78909C),
    HttpMethod.options: Color(0xFF7B1FA2),
  };

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _urlFocus = FocusNode();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  /// Triggers the send action.
  void _send() {
    _urlFocus.unfocus();
    if (widget.onSend != null) {
      widget.onSend!();
    } else {
      ref.read(sendRequestProvider)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(currentRequestProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final recentAsync = ref.watch(recentEndpointsProvider);
    final isWide = MediaQuery.of(context).size.width >= 600;

    // Cache recent endpoints when they arrive.
    recentAsync.whenData((list) {
      if (list != _recentEndpoints) {
        _recentEndpoints = list;
      }
    });

    // Sync the controller when the URL changes externally.
    if (_urlController.text != formState.url && !_urlFocus.hasFocus) {
      _urlController.text = formState.url;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // ── HTTP Method selector: horizontal scrollable chips ─────────
            SizedBox(
              height: 36,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: HttpMethod.values.map((method) {
                    final isSelected = formState.method == method;
                    final color =
                        _methodColors[method] ?? Colors.grey;

                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Material(
                        color: isSelected
                            ? color
                            : color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: () {
                            ref
                                .read(currentRequestProvider.notifier)
                                .setMethod(method);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: isSelected
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: color, width: 1.5),
                                  )
                                : null,
                            child: Text(
                              method.name.toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // ── URL text field with autocomplete ──────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.toLowerCase();
                      if (query.isEmpty) return _recentEndpoints;
                      return _recentEndpoints
                          .where((e) => e.toLowerCase().contains(query))
                          .toList();
                    },
                    onSelected: (url) {
                      _urlController.text = url;
                      ref
                          .read(currentRequestProvider.notifier)
                          .setUrl(url);
                    },
                    fieldViewBuilder: (context, controller, node, _) {
                      if (controller.text != formState.url) {
                        controller.text = formState.url;
                        controller.selection = TextSelection.collapsed(
                          offset: formState.url.length,
                        );
                      }
                      controller.addListener(() {
                        if (controller.text != formState.url) {
                          ref
                              .read(currentRequestProvider.notifier)
                              .setUrl(controller.text);
                        }
                      });

                      return TextField(
                        controller: controller,
                        focusNode: node,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: isWide ? 'monospace' : null,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Enter request URL (e.g. https://api.example.com/users)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                              maxHeight: 200,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Symbols.history,
                                          size: 16,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: theme.textTheme.bodySmall,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),

            // ── Send button ───────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: isLoading ? null : _send,
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Symbols.send, size: 18),
                label: Text(
                  isWide ? 'Send' : '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}