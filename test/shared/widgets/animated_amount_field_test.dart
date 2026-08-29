import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitpay/shared/widgets/animated_amount_field.dart';

Widget _host(TextEditingController controller) {
  return MaterialApp(
    // Give the field a theme with filled inputs + a focused border, matching
    // the real app, to prove the field strips them instead of ballooning.
    theme: ThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.green,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.purple, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    home: Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('₹'),
            AnimatedAmountField(
              controller: controller,
              style: const TextStyle(fontSize: 48, color: Colors.red),
              hintStyle: const TextStyle(fontSize: 48, color: Colors.grey),
              cursorColor: Colors.red,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the hint when empty', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // Hint '0' should be visible (in the overlay Text, not just the field).
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('renders each digit and sizes to content, not full width',
      (tester) async {
    final controller = TextEditingController(text: '123');
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    // Each digit is rendered as its own visible Text.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // The field must hug its content, not stretch to the full screen width
    // (regression guard for the theme border/fill ballooning bug).
    final fieldWidth = tester.getSize(find.byType(AnimatedAmountField)).width;
    expect(fieldWidth, lessThan(300));
  });

  testWidgets('updates rendered digits when the value changes',
      (tester) async {
    final controller = TextEditingController(text: '5');
    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    controller.text = '58';
    await tester.pumpAndSettle();
    // The newly typed digit is rendered as its own animated Text overlay
    // (unambiguous: '8' is not the full field text, so it can only be a digit).
    expect(find.text('8'), findsOneWidget);
  });
}
