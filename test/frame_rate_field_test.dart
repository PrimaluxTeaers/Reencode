import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:reencode/bounded_number_field.dart";
import "package:reencode/frame_rate_field.dart";

void main() {
  testWidgets("bounded field commits on submit and clamps both ends", (
    WidgetTester tester,
  ) async {
    int value = 30;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoundedNumberField(
            value: value,
            min: 24,
            max: 60,
            onChanged: (int next) => value = next,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), "99");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 60);

    await tester.enterText(find.byType(TextField), "9");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 24);
  });

  testWidgets("frame rate field caps typing at 60 and exposes 90/120", (
    WidgetTester tester,
  ) async {
    int value = 30;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => FrameRateField(
              value: value,
              onChanged: (int next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    expect(find.text("90 fps"), findsOneWidget);
    expect(find.text("120 fps"), findsOneWidget);
    expect(find.text("144 fps (high risk)"), findsNothing);

    await tester.enterText(find.byType(TextField), "90");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(value, 60);

    await tester.tap(find.text("120 fps"));
    await tester.pump();
    expect(value, 120);
  });

  testWidgets("four taps on 120 reveal the 144 dialog", (
    WidgetTester tester,
  ) async {
    int value = 30;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => FrameRateField(
              value: value,
              onChanged: (int next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    for (int i = 0; i < 4; i++) {
      await tester.tap(find.text("120 fps"));
      await tester.pump();
    }
    expect(find.text("Unlock 144 fps?"), findsOneWidget);
    expect(value, 120);
  });
}
