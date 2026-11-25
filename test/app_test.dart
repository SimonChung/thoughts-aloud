import 'package:flutter_test/flutter_test.dart';
import 'package:thoughts_aloud/main.dart';

void main() {
  testWidgets('啟動後顯示想唸', (tester) async {
    await tester.pumpWidget(const ThoughtsAloudApp());
    expect(find.text('想唸'), findsOneWidget);
  });
}
