/// Integration tests for the API Tester app.
///
/// These tests exercise the full app lifecycle: navigating through screens,
/// creating workspaces, sending requests, and verifying responses.
///
/// They require a running Flutter app on a device/emulator and network
/// access to jsonplaceholder.typicode.com.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:api_tester/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full Flow Integration Tests', () {
    testWidgets('Test 1: Create workspace and send GET request to jsonplaceholder',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // --- Step 1: Wait for the app to load ---
      // The app should show the main shell with workspace list.
      await tester.pumpAndSettle();

      // --- Step 2: Create a workspace named "Test Workspace" ---
      // Look for a button to create a new workspace (e.g., FAB or empty state action).
      final createWorkspaceButtons = find.byType(FloatingActionButton);
      if (createWorkspaceButtons.evaluate().isNotEmpty) {
        await tester.tap(createWorkspaceButtons.first);
        await tester.pumpAndSettle();
      } else {
        // Try to find an empty state "Create" button.
        final emptyStateAction = find.text('Create Workspace');
        if (emptyStateAction.evaluate().isNotEmpty) {
          await tester.tap(emptyStateAction);
          await tester.pumpAndSettle();
        }
      }

      // Enter workspace name in the dialog/form.
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Test Workspace');
      await tester.pumpAndSettle();

      // Save the workspace.
      final saveButton = find.byType(FilledButton);
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // --- Step 3: Navigate to request builder ---
      // Find and tap the workspace or a "new request" button.
      final testWorkspace = find.text('Test Workspace');
      if (testWorkspace.evaluate().isNotEmpty) {
        await tester.tap(testWorkspace);
        await tester.pumpAndSettle();
      }

      // --- Step 4: Enter URL ---
      final urlField = find.byType(TextField);
      // Find the URL text field (usually the second one after method chips).
      if (urlField.evaluate().length >= 2) {
        await tester.enterText(urlField.last, 'https://jsonplaceholder.typicode.com/posts/1');
      } else {
        await tester.enterText(urlField.first, 'https://jsonplaceholder.typicode.com/posts/1');
      }
      await tester.pumpAndSettle();

      // --- Step 5: Ensure GET is selected ---
      final getChip = find.text('GET');
      if (getChip.evaluate().isNotEmpty) {
        await tester.tap(getChip.first);
        await tester.pumpAndSettle();
      }

      // --- Step 6: Send request ---
      final sendButton = find.textContaining('Send');
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // --- Step 7: Verify response ---
        // Should show status code 200.
        expect(find.textContaining('200'), findsOneWidget);

        // Response body should contain JSON with expected keys.
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // The response body from jsonplaceholder contains "userId", "id", "title", "body".
        expect(
          find.textContaining('userId'),
          findsWidgets,
          reason: 'Response body should contain "userId" from jsonplaceholder',
        );
      }
    });

    testWidgets('Test 2: Send POST request with JSON body', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Wait for the app to be ready.
      await tester.pumpAndSettle();

      // --- Step 1: Navigate to request builder ---
      // Assuming we're on the main screen, look for a way to create a request.
      final addButtons = find.byType(FloatingActionButton);
      if (addButtons.evaluate().isNotEmpty) {
        await tester.tap(addButtons.first);
        await tester.pumpAndSettle();
      }

      // --- Step 2: Select POST method ---
      final postChip = find.text('POST');
      if (postChip.evaluate().isNotEmpty) {
        await tester.tap(postChip.first);
        await tester.pumpAndSettle();
      }

      // --- Step 3: Enter URL ---
      final urlFields = find.byType(TextField);
      if (urlFields.evaluate().isNotEmpty) {
        await tester.enterText(
          urlFields.last,
          'https://jsonplaceholder.typicode.com/posts',
        );
        await tester.pumpAndSettle();
      }

      // --- Step 4: Switch to body editor and set body type to raw/JSON ---
      // Look for the "Body" tab.
      final bodyTab = find.text('Body');
      if (bodyTab.evaluate().isNotEmpty) {
        await tester.tap(bodyTab.first);
        await tester.pumpAndSettle();
      }

      // Look for "Raw" or "JSON" option.
      final rawOption = find.text('Raw');
      if (rawOption.evaluate().isNotEmpty) {
        await tester.tap(rawOption.first);
        await tester.pumpAndSettle();
      }

      // --- Step 5: Enter JSON body ---
      // Find the body text field.
      final bodyFields = find.byType(TextField);
      if (bodyFields.evaluate().isNotEmpty) {
        await tester.enterText(
          bodyFields.last,
          '{"title": "test", "body": "hello", "userId": 1}',
        );
        await tester.pumpAndSettle();
      }

      // --- Step 6: Send request ---
      final sendButton = find.textContaining('Send');
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // --- Step 7: Verify response ---
        // Should show status code 201 (Created).
        expect(find.textContaining('201'), findsOneWidget);

        // Response should contain the title we sent.
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.textContaining('test'),
          findsWidgets,
          reason: 'Response body should contain the title we posted',
        );
      }
    });

    testWidgets('Test 3: cURL import from import screen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Wait for the app to be ready.
      await tester.pumpAndSettle();

      // --- Step 1: Navigate to cURL import tool ---
      // Find the Tools or Import section.
      // This depends on the app's navigation. Look for a tools button.
      final toolsButton = find.text('Tools');
      if (toolsButton.evaluate().isNotEmpty) {
        await tester.tap(toolsButton.first);
        await tester.pumpAndSettle();
      }

      // Find "cURL Import" option.
      final curlImport = find.text('cURL Import');
      if (curlImport.evaluate().isNotEmpty) {
        await tester.tap(curlImport.first);
        await tester.pumpAndSettle();
      }

      // --- Step 2: Enter cURL command ---
      final curlInput = find.byType(TextField);
      if (curlInput.evaluate().isNotEmpty) {
        await tester.enterText(
          curlInput.first,
          'curl -X GET https://jsonplaceholder.typicode.com/users/1',
        );
        await tester.pumpAndSettle();
      }

      // --- Step 3: Tap import ---
      final importButton = find.textContaining('Import');
      if (importButton.evaluate().isNotEmpty) {
        await tester.tap(importButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // --- Step 4: Verify imported request ---
      // After import, the method should be GET and URL should be correct.
      // The app may navigate to the request builder or show a success message.
      // Verify the URL is populated.
      final urlFields = find.byType(TextField);
      if (urlFields.evaluate().isNotEmpty) {
        // One of the text fields should contain the imported URL.
        final foundUrl = urlFields.evaluate().any((widget) {
          final tf = widget as TextField;
          return tf.controller?.text.contains('jsonplaceholder.typicode.com') ?? false;
        });
        expect(foundUrl, isTrue,
            reason: 'Imported cURL URL should appear in the URL field');
      }

      // Verify GET is still selected.
      expect(find.text('GET'), findsWidgets);
    });
  });
}