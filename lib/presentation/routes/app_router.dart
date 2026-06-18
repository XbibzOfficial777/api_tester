/// @file app_router.dart
/// @brief Centralised GoRouter configuration for the API Tester application.
///
/// Defines every named route and its corresponding screen widget.
/// The router supports path parameters (e.g. `:id`) for edit-mode screens
/// and optional query parameters where needed.
///
/// Usage:
/// ```dart
/// // Navigate to the request builder in edit mode.
/// context.go('/request/edit/abc-123');
///
/// // Push the collection runner onto the navigation stack.
/// context.push('/collection/runner/xyz-789');
/// ```
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/collection/collection_editor_screen.dart';
import '../screens/collection/collection_runner_screen.dart';
import '../screens/collection/collections_screen.dart';
import '../screens/environment/environment_editor_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/import/import_screen.dart';
import '../screens/main_shell.dart';
import '../screens/request_builder/request_builder_screen.dart';
import '../screens/response/response_analyzer_screen.dart';
import '../screens/settings/proxy_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tools/code_generator_screen.dart';
import '../screens/tools/curl_import_screen.dart';
import '../screens/tools/diff_tool_screen.dart';
import '../screens/tools/graphql_screen.dart';
import '../screens/tools/jwt_decoder_screen.dart';
import '../screens/tools/schema_generator_screen.dart';
import '../screens/tools/websocket_screen.dart';
import '../screens/workspace/workspace_editor_screen.dart';

/// Global [GoRouter] instance used by [MaterialApp.router].
///
/// All route changes should go through this router rather than a manual
/// [Navigator] so that deep-links and the browser URL bar stay in sync.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // -----------------------------------------------------------------------
    // Main shell — bottom nav / sidebar wrapper
    // -----------------------------------------------------------------------
    StatefulShellRoute.indexedStack(
      builder: _buildShell,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'request',
              builder: (context, state) => const RequestBuilderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/collections',
              name: 'collections',
              builder: (context, state) => const CollectionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              name: 'history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // -----------------------------------------------------------------------
    // Request builder — new & edit
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/request/new',
      name: 'requestNew',
      builder: (context, state) => const RequestBuilderScreen(),
    ),
    GoRoute(
      path: '/request/edit/:id',
      name: 'requestEdit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RequestBuilderScreen(requestId: id);
      },
    ),

    // -----------------------------------------------------------------------
    // Response analyzer
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/response-analyzer',
      name: 'responseAnalyzer',
      builder: (context, state) => const ResponseAnalyzerScreen(),
    ),

    // -----------------------------------------------------------------------
    // Workspace editor — new & edit
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/workspace/new',
      name: 'workspaceNew',
      builder: (context, state) => const WorkspaceEditorScreen(),
    ),
    GoRoute(
      path: '/workspace/edit/:id',
      name: 'workspaceEdit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WorkspaceEditorScreen(workspaceId: id);
      },
    ),

    // -----------------------------------------------------------------------
    // Collection editor & runner
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/collection/edit/:id',
      name: 'collectionEdit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CollectionEditorScreen(collectionId: id);
      },
    ),
    GoRoute(
      path: '/collection/runner/:id',
      name: 'collectionRunner',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CollectionRunnerScreen(collectionId: id);
      },
    ),

    // -----------------------------------------------------------------------
    // Environment editor
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/environment/edit/:id',
      name: 'environmentEdit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EnvironmentEditorScreen(environmentId: id);
      },
    ),

    // -----------------------------------------------------------------------
    // Import
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/import',
      name: 'import',
      builder: (context, state) => const ImportScreen(),
    ),

    // -----------------------------------------------------------------------
    // Settings sub-screens
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/settings/proxy',
      name: 'proxySettings',
      builder: (context, state) => const ProxySettingsScreen(),
    ),

    // -----------------------------------------------------------------------
    // Tools
    // -----------------------------------------------------------------------
    GoRoute(
      path: '/tools/code-gen',
      name: 'codeGenerator',
      builder: (context, state) => const CodeGeneratorScreen(),
    ),
    GoRoute(
      path: '/tools/curl-import',
      name: 'curlImport',
      builder: (context, state) => const CurlImportScreen(),
    ),
    GoRoute(
      path: '/tools/websocket',
      name: 'websocket',
      builder: (context, state) => const WebSocketScreen(),
    ),
    GoRoute(
      path: '/tools/graphql',
      name: 'graphql',
      builder: (context, state) => const GraphQLScreen(),
    ),
    GoRoute(
      path: '/tools/jwt-decoder',
      name: 'jwtDecoder',
      builder: (context, state) => const JwtDecoderScreen(),
    ),
    GoRoute(
      path: '/tools/diff',
      name: 'diffTool',
      builder: (context, state) => const DiffToolScreen(),
    ),
    GoRoute(
      path: '/tools/schema-gen',
      name: 'schemaGenerator',
      builder: (context, state) => const SchemaGeneratorScreen(),
    ),
  ],
  // Show a simple "not found" page for unregistered routes.
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page Not Found')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('404 — The requested page does not exist.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);

/// Builds the [MainShell] wrapper that provides the bottom navigation bar
/// and the app bar. The [child] parameter is the current branch content.
Widget _buildShell(
  BuildContext context,
  GoRouterState state,
  StatefulNavigationShell navigationShell,
) {
  return MainShell(navigationShell: navigationShell);
}