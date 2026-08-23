import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/app.dart';

void main() {
  testWidgets('App boots to Dynamic Safety Map', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuakeRouteApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dynamic Safety Map'), findsOneWidget);
    expect(find.text('QuakeRoute'), findsOneWidget);
  });
}
