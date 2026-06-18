import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'package:api_tester/presentation/screens/request_builder/widgets/url_input_bar.dart';

void main() {
  group('UrlInputBar', () {
    testWidgets('all HTTP method chips are shown', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 7 HTTP methods should be shown.
      for (final method in HttpMethod.values) {
        expect(find.text(method.name.toUpperCase()), findsOneWidget);
      }
    });

    testWidgets('URL input field exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find a TextField.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('send button exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
            isLoadingProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find a FilledButton.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('loading state shows indicator instead of icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
            isLoadingProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // When loading, a CircularProgressIndicator should be shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping a method chip changes the selected method',
        (tester) async {
      final notifier = RequestFormNotifier();
      expect(notifier.state.method, equals(HttpMethod.get));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => notifier),
            isLoadingProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the POST chip.
      await tester.tap(find.text('POST'));
      await tester.pumpAndSettle();

      expect(notifier.state.method, equals(HttpMethod.post));
    });

    testWidgets('onSend callback is invoked when send is tapped', (tester) async {
      var sendCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
            isLoadingProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UrlInputBar(
                onSend: () {
                  sendCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the send button.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('send button is disabled when loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRequestProvider.overrideWith((ref) => RequestFormNotifier()),
            isLoadingProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UrlInputBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });
}