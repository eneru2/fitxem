import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitxem/app.dart';

void main() {
  testWidgets('App renders login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JustClockApp()));
    await tester.pumpAndSettle();
    expect(find.text('Fitxem'), findsOneWidget);
  });
}
