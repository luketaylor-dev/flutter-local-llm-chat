import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llm_interface/main.dart';

void main() {
  testWidgets('App initializes and shows home page', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LlmApp()));

    // Verify that the app bar title is displayed.
    expect(find.text('LLM Chat'), findsWidgets);
  });
}
