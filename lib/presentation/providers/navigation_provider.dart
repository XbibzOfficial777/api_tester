/// @file navigation_provider.dart
/// @brief Riverpod providers for bottom navigation and request selection.
///
/// Manages the currently visible tab (Request, Collections, History,
/// Settings) and the optional request ID used to navigate to edit an
/// existing request.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Navigation Index
// ---------------------------------------------------------------------------

/// The index of the currently selected bottom navigation tab.
///
/// | Index | Tab        |
/// |-------|------------|
/// |   0   | Request    |
/// |   1   | Collections |
/// |   2   | History    |
/// |   3   | Settings   |
///
/// Watch this provider in the [BottomNavigationBar] to highlight the
/// active tab and switch the body content.
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Selected Request
// ---------------------------------------------------------------------------

/// The ID of the request selected for editing (from a list, history, etc.).
///
/// Set to a non-null value to trigger navigation to the request editor
/// pre-populated with that request's data. Set back to `null` after the
/// editor has loaded the request to avoid re-triggering on rebuilds.
final selectedRequestIdProvider = StateProvider<String?>((ref) => null);