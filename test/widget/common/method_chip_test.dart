import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/presentation/widgets/common/method_chip.dart';

void main() {
  group('MethodChip', () {
    for (final method in HttpMethod.values) {
      testWidgets('displays correct method text for ${method.name}',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: method),
            ),
          ),
        );

        final expectedLabel = method.name.toUpperCase();
        expect(find.text(expectedLabel), findsOneWidget);
      });
    }

    group('color for each HTTP method', () {
      testWidgets('GET has green color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.get),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('GET'));
        expect(textWidget.style?.color, equals(const Color(0xFF43A047)));
      });

      testWidgets('POST has blue color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.post),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('POST'));
        expect(textWidget.style?.color, equals(const Color(0xFF1E88E5)));
      });

      testWidgets('PUT has orange color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.put),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('PUT'));
        expect(textWidget.style?.color, equals(const Color(0xFFFB8C00)));
      });

      testWidgets('PATCH has teal color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.patch),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('PATCH'));
        expect(textWidget.style?.color, equals(const Color(0xFF00897B)));
      });

      testWidgets('DELETE has red color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.delete),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('DELETE'));
        expect(textWidget.style?.color, equals(const Color(0xFFE53935)));
      });

      testWidgets('HEAD has grey color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.head),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('HEAD'));
        expect(textWidget.style?.color, equals(const Color(0xFF78909C)));
      });

      testWidgets('OPTIONS has purple color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MethodChip(method: HttpMethod.options),
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('OPTIONS'));
        expect(textWidget.style?.color, equals(const Color(0xFF7B1FA2)));
      });
    });

    testWidgets('has bold font weight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MethodChip(method: HttpMethod.get),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('GET'));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('respects custom fontSize', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MethodChip(method: HttpMethod.get, fontSize: 20),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('GET'));
      expect(textWidget.style?.fontSize, equals(20));
    });
  });
}