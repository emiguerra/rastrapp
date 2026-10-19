import 'package:flutter_test/flutter_test.dart';
import 'package:rastrapp/main.dart';

void main() {
  testWidgets('muestra el botón para tomar foto', (tester) async {
    await tester.pumpWidget(const Rastrapp());
    expect(find.text('Tomar foto'), findsOneWidget);
  });
}
