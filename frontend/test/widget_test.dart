import 'package:flutter_test/flutter_test.dart';
import 'package:fareast_worker_app/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('遠東智工'), findsWidgets);
  });
}
