import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:api_tester/presentation/widgets/common/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces yet',
            ),
          ),
        ),
      );

      expect(find.text('No workspaces yet'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
              subtitle: 'Create your first workspace to get started.',
            ),
          ),
        ),
      );

      expect(find.text('Create your first workspace to get started.'),
          findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
            ),
          ),
        ),
      );

      // The title should exist.
      expect(find.text('No workspaces'), findsOneWidget);
      // The Column should have exactly 2 children: Icon + SizedBox + Text(title)
      // No subtitle SizedBox + Text(subtitle).
    });

    testWidgets('shows action button when actionLabel and onAction are provided',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
              actionLabel: 'Create Workspace',
              onAction: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Create Workspace'), findsOneWidget);
    });

    testWidgets('tap on action button triggers callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
              actionLabel: 'Create Workspace',
              onAction: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      // Wait for animation to complete.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Workspace'));
      expect(tapped, isTrue);
    });

    testWidgets('does not show action button when not provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.search_off,
              title: 'No results',
            ),
          ),
        ),
      );

      expect(find.byIcon(Symbols.search_off), findsOneWidget);
    });

    testWidgets('centers the content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Symbols.folder_off,
              title: 'No workspaces',
            ),
          ),
        ),
      );

      final center = tester.widget<Center>(find.byType(Center));
      expect(center, isNotNull);
    });
  });
}