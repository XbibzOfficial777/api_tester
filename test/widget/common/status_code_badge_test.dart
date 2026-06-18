import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_tester/core/theme/app_theme.dart';
import 'package:api_tester/presentation/widgets/common/status_code_badge.dart';

void main() {
  group('StatusCodeBadge', () {
    testWidgets('displays the status code number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 200),
          ),
        ),
      );

      expect(find.textContaining('200'), findsOneWidget);
    });

    testWidgets('displays reason phrase for known code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 404),
          ),
        ),
      );

      expect(find.textContaining('404'), findsOneWidget);
      expect(find.textContaining('Not Found'), findsOneWidget);
    });

    testWidgets('displays "N/A" when statusCode is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: const StatusCodeBadge(statusCode: null),
          ),
        ),
      );

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('displays "N/A" when statusCode is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: const StatusCodeBadge(statusCode: 0),
          ),
        ),
      );

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('correct color for 2xx status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 200),
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byType(RichText),
        ),
      );
      // First span should be the status number with green color.
      final statusSpan = richText.text as TextSpan;
      expect(statusSpan.children!.first, isA<TextSpan>());
      final codeSpan = statusSpan.children!.first as TextSpan;
      expect(codeSpan.style?.color, equals(AppTheme.status2xx));
    });

    testWidgets('correct color for 3xx status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 301),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(RichText),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(AppTheme.status3xx.withOpacity(0.15)));
    });

    testWidgets('correct color for 4xx status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 400),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(RichText),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(AppTheme.status4xx.withOpacity(0.15)));
    });

    testWidgets('correct color for 5xx status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 500),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(RichText),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(AppTheme.status5xx.withOpacity(0.15)));
    });

    testWidgets('hides reason phrase when showReasonPhrase is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: const StatusCodeBadge(
              statusCode: 200,
              showReasonPhrase: false,
            ),
          ),
        ),
      );

      expect(find.text('200'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('shows generic range for unknown status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatusCodeBadge(statusCode: 299),
          ),
        ),
      );

      expect(find.textContaining('299'), findsOneWidget);
      expect(find.textContaining('Success'), findsOneWidget);
    });
  });
}