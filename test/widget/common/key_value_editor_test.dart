import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_tester/presentation/widgets/common/key_value_editor.dart';

void main() {
  group('KeyValueEditor', () {
    testWidgets('renders initial entries', (tester) async {
      final entries = [
        KeyValueEntry(key: 'Content-Type', value: 'application/json'),
        KeyValueEntry(key: 'Accept', value: 'text/plain'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyValueEditor(
                entries: entries,
                onChanged: (_) {},
                keyHint: 'Header name',
                valueHint: 'Header value',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the initial key values in the text fields.
      expect(find.text('Content-Type'), findsOneWidget);
      expect(find.text('application/json'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('text/plain'), findsOneWidget);
    });

    testWidgets('renders hint labels for key and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyValueEditor(
                entries: const [],
                onChanged: (_) {},
                keyHint: 'Key Name',
                valueHint: 'Key Value',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Key Name'), findsOneWidget);
      expect(find.text('Key Value'), findsOneWidget);
    });

    testWidgets('add new entry when add button is tapped', (tester) async {
      List<KeyValueEntry> currentEntries = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyValueEditor(
                entries: const [],
                onChanged: (updated) {
                  currentEntries = updated;
                },
                keyHint: 'Key',
                valueHint: 'Value',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the "Add" button.
      final addButton = find.textContaining('Add');
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // The callback should have been called with one entry.
      expect(currentEntries, hasLength(1));
      expect(currentEntries.first.key, isEmpty);
      expect(currentEntries.first.value, isEmpty);
      expect(currentEntries.first.isEnabled, isTrue);
    });

    testWidgets('remove entry when delete button is tapped', (tester) async {
      List<KeyValueEntry> currentEntries = [
        KeyValueEntry(key: 'X-Test', value: 'value'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return KeyValueEditor(
                    entries: currentEntries,
                    onChanged: (updated) {
                      setState(() {
                        currentEntries = List.of(updated);
                      });
                    },
                    keyHint: 'Key',
                    valueHint: 'Value',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the close/remove icon button.
      final removeButtons = find.byIcon(Icons.close);
      // There may be multiple icons, but we need the remove one.
      // Since only one entry, there should be one close button.
      expect(removeButtons, findsWidgets);

      // Tap the first remove button.
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(currentEntries, isEmpty);
    });

    testWidgets('enable/disable toggle changes entry state', (tester) async {
      List<KeyValueEntry> currentEntries = [
        KeyValueEntry(key: 'Authorization', value: 'Bearer token', isEnabled: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return KeyValueEditor(
                    entries: currentEntries,
                    onChanged: (updated) {
                      setState(() {
                        currentEntries = List.of(updated);
                      });
                    },
                    keyHint: 'Key',
                    valueHint: 'Value',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Switch widget.
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue);

      // Tap the switch to disable.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // After toggling, the entry should be disabled.
      expect(currentEntries.first.isEnabled, isFalse);
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KeyValueEditor(
                entries: const [],
                onChanged: (_) {},
                keyHint: 'Key',
                valueHint: 'Value',
                title: 'Request Headers',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Request Headers'), findsOneWidget);
    });
  });
}