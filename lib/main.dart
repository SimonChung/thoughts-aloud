import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const ThoughtsAloudApp());
}

class ThoughtsAloudApp extends StatelessWidget {
  const ThoughtsAloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '想唸 Thoughts Aloud',
      home: Scaffold(body: Center(child: Text('想唸'))),
    );
  }
}
