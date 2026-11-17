import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:reencode/dialogs.dart";
import "package:reencode/main.dart";
import "package:reencode/page_route.dart";

void main() {
  testWidgets("home shows all five codecs and a settings entry", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReencodeApp());
    await tester.pumpAndSettle();

    expect(find.text("MPEG-4"), findsWidgets);
    expect(find.text("H.264"), findsWidgets);
    expect(find.text("H.265"), findsWidgets);
    expect(find.text("VP9"), findsWidgets);
    expect(find.textContaining("AV1"), findsWidgets);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets(
    "settings route slides/fades in and out instead of popping instantly",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<bool>(
                    appPageRoute(
                      builder: (_) => Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text("Settings"),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text("Back"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text("Settings"), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text("Settings"), findsOneWidget);

      await tester.tap(find.text("Back"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text("Settings"), findsOneWidget);
      expect(find.text("Open"), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text("Settings"), findsNothing);
      expect(find.text("Open"), findsOneWidget);
    },
  );

  testWidgets("dialog buttons are tappable and return the right result", (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AppDialog(
                      icon: Icons.info_outline_rounded,
                      title: "Test",
                      message: "Body",
                      primaryLabel: "Yes",
                      primaryResult: true,
                      secondaryLabel: "No",
                      secondaryResult: false,
                    ),
                  );
                },
                child: const Text("Show"),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Show"));
    await tester.pumpAndSettle();
    expect(find.text("Test"), findsOneWidget);
    await tester.tap(find.text("No"));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text("Test"), findsNothing);
  });
}
