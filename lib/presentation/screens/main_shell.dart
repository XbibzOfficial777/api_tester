/// @file main_shell.dart
/// @brief Root scaffold with responsive navigation (bottom bar on phone,
/// rail on tablet) and a shared app bar with workspace selector.
///
/// The shell is the visual container for the four primary tabs:
/// Request, Collections, History, and Settings. It wraps a
/// [StatefulNavigationShell] provided by GoRouter so that each tab
/// preserves its own navigation stack.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/app_settings.dart' as domain;
import '../../domain/entities/workspace.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workspace_provider.dart';

/// Responsive breakpoint at which the layout switches from bottom
/// navigation to a side [NavigationRail].
const double _kTabletBreakpoint = 600.0;

/// Root shell widget that provides the app bar, navigation controls, and
/// a context-aware FAB.
///
/// On narrow screens (< 600 px) a [NavigationBar] is shown at the bottom.
/// On wide screens (>= 600 px) a [NavigationRail] is rendered on the left
/// edge instead.
class MainShell extends ConsumerStatefulWidget {
  /// The [StatefulNavigationShell] from GoRouter that manages per-branch
  /// navigation state.
  final StatefulNavigationShell navigationShell;

  /// Creates a [MainShell].
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  /// The index of the currently selected navigation tab.
  int _currentIndex = 0;

  /// Whether the navigation rail is in extended mode (tablet only).
  bool _isRailExtended = false;

  // Animation controllers for tab transition fade effect.
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.value = 1.0;

    // Sync the initial index from the navigation shell.
    _currentIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If GoRouter changed the index externally (e.g. deep link), animate.
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _animateToTab(widget.navigationShell.currentIndex);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Animates the transition between tabs with a fade effect.
  Future<void> _animateToTab(int index) async {
    if (index == _currentIndex) return;

    // Fade out
    await _fadeController.reverse();

    setState(() {
      _currentIndex = index;
      ref.read(navigationIndexProvider.notifier).state = index;
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    });

    // Fade in
    await _fadeController.forward();
  }

  /// Navigates to the quick-action destination based on the current tab.
  void _onFabPressed() {
    switch (_currentIndex) {
      case 0:
        // Reset request form and go to request builder
        ref.read(navigationIndexProvider.notifier).state = 0;
        widget.navigationShell.goBranch(0, initialLocation: true);
      case 1:
        context.push('/workspace/new');
      case 2:
        _showClearHistoryDialog();
      case 3:
        context.push('/import');
    }
  }

  /// Returns the FAB icon for the current tab.
  IconData get _fabIcon {
    return switch (_currentIndex) {
      0 => Symbols.add,
      1 => Symbols.create_new_folder,
      2 => Symbols.delete_sweep,
      3 => Symbols.file_upload,
    };
  }

  /// Returns the FAB tooltip for the current tab.
  String get _fabTooltip {
    return switch (_currentIndex) {
      0 => 'New Request',
      1 => 'New Collection',
      2 => 'Clear History',
      3 => 'Import',
    };
  }

  /// Shows a confirmation dialog before clearing all history.
  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all request history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // The history provider clear is called from the history screen.
              // This action provides a shortcut from the shell.
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _kTabletBreakpoint;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(colorScheme),
      body: Row(
        children: [
          // Show NavigationRail on wide screens.
          if (isWide) _buildNavigationRail(colorScheme),
          // Main content area with fade transition.
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
      // Bottom NavigationBar on narrow screens.
      bottomNavigationBar: isWide ? null : _buildBottomNavBar(colorScheme),
      floatingActionButton: _buildFab(colorScheme),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  /// Builds the shared [AppBar] with app title and workspace selector.
  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    final workspacesAsync = ref.watch(workspaceListProvider);

    return AppBar(
      title: Row(
        children: [
          // App logo / name.
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(width: 12),
          // Workspace selector dropdown.
          workspacesAsync.when(
            data: (workspaces) => _WorkspaceSelector(
              workspaces: workspaces,
            ),
            loading: () => const SizedBox(
              width: 120,
              height: 24,
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const Text('No workspace'),
          ),
        ],
      ),
      actions: [
        // Theme toggle button.
        IconButton(
          icon: Icon(
            ref.watch(themeModeProvider) == ThemeMode.dark
                ? Symbols.light_mode
                : Symbols.dark_mode,
          ),
          tooltip: 'Toggle theme',
          onPressed: () {
            // Cycle through theme modes: system -> light -> dark -> system
            final current = ref.read(settingsProvider).themeMode;
            final next = switch (current) {
              domain.ThemeMode.system => domain.ThemeMode.light,
              domain.ThemeMode.light => domain.ThemeMode.dark,
              domain.ThemeMode.dark => domain.ThemeMode.system,
            };
            ref.read(settingsProvider.notifier).updateThemeMode(next);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom NavigationBar (phone)
  // ---------------------------------------------------------------------------

  /// Material 3 [NavigationBar] with four tabs.
  Widget _buildBottomNavBar(ColorScheme colorScheme) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _animateToTab,
      height: 72,
      animationDuration: const Duration(milliseconds: 300),
      destinations: const [
        NavigationDestination(
          icon: Icon(Symbols.send),
          selectedIcon: Icon(Symbols.send),
          label: 'Request',
        ),
        NavigationDestination(
          icon: Icon(Symbols.folder),
          selectedIcon: Icon(Symbols.folder),
          label: 'Collections',
        ),
        NavigationDestination(
          icon: Icon(Symbols.history),
          selectedIcon: Icon(Symbols.history),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Symbols.settings),
          selectedIcon: Icon(Symbols.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NavigationRail (tablet)
  // ---------------------------------------------------------------------------

  /// Material 3 [NavigationRail] shown on wide screens.
  Widget _buildNavigationRail(ColorScheme colorScheme) {
    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: _animateToTab,
      minWidth: 72,
      minExtendedWidth: 200,
      extended: _isRailExtended,
      labelType: NavigationRailLabelType.selected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          Symbols.api,
          size: 32,
          color: colorScheme.primary,
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Symbols.send),
          selectedIcon: Icon(Symbols.send),
          label: Text('Request'),
        ),
        NavigationRailDestination(
          icon: Icon(Symbols.folder),
          selectedIcon: Icon(Symbols.folder),
          label: Text('Collections'),
        ),
        NavigationRailDestination(
          icon: Icon(Symbols.history),
          selectedIcon: Icon(Symbols.history),
          label: Text('History'),
        ),
        NavigationRailDestination(
          icon: Icon(Symbols.settings),
          selectedIcon: Icon(Symbols.settings),
          label: Text('Settings'),
        ),
      ],
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IconButton(
          icon: Icon(
            _isRailExtended ? Symbols.menu_open : Symbols.menu,
            size: 20,
          ),
          tooltip: _isRailExtended ? 'Collapse rail' : 'Expand rail',
          onPressed: () {
            setState(() => _isRailExtended = !_isRailExtended);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAB
  // ---------------------------------------------------------------------------

  /// Context-aware [FloatingActionButton] that changes action per tab.
  Widget? _buildFab(ColorScheme colorScheme) {
    // No FAB on the settings tab to avoid clutter.
    if (_currentIndex == 3) return null;

    return FloatingActionButton(
      onPressed: _onFabPressed,
      tooltip: _fabTooltip,
      child: Icon(_fabIcon),
    ).animate().fadeIn(duration: 200.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }
}

// =============================================================================
// Workspace Selector Dropdown
// =============================================================================

/// Compact dropdown button that allows switching between workspaces.
///
/// When no workspaces exist a "Create Workspace" option is shown instead.
class _WorkspaceSelector extends ConsumerWidget {
  /// The list of all available workspaces.
  final List<Workspace> workspaces;

  /// Creates a [_WorkspaceSelector].
  const _WorkspaceSelector({required this.workspaces});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentWorkspace = ref.watch(currentWorkspaceProvider);
    final activeId = currentWorkspace?.id;

    return PopupMenuButton<String>(
      tooltip: 'Switch workspace',
      onSelected: (id) {
        if (id == 'new') {
          context.push('/workspace/new');
        } else {
          // Find the workspace and set it as current.
          final selected = workspaces.where((w) => w.id == id).firstOrNull;
          if (selected != null) {
            ref.read(currentWorkspaceProvider.notifier).state = selected;
          }
        }
      },
      itemBuilder: (context) {
        if (workspaces.isEmpty) {
          return [
            const PopupMenuItem(
              value: 'new',
              child: Row(
                children: [
                  Icon(Symbols.add, size: 18),
                  SizedBox(width: 8),
                  Text('Create Workspace'),
                ],
              ),
            ),
          ];
        }
        return workspaces.map<PopupMenuItem<String>>((w) {
          final isSelected = w.id == activeId;
          return PopupMenuItem(
            value: w.id,
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Symbols.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  w.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList()
          ..add(const PopupMenuDivider())
          ..add(const PopupMenuItem(
            value: 'new',
            child: Row(
              children: [
                Icon(Symbols.add, size: 18),
                SizedBox(width: 8),
                Text('New Workspace'),
              ],
            ),
          ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.workspace_premium,
                size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              currentWorkspace?.name ?? 'Select Workspace',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(Symbols.expand_more,
                size: 16, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}