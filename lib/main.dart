import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'library_page.dart';

void main() => runApp(const ThoughtsAloudApp());

class ThoughtsAloudApp extends StatelessWidget {
  const ThoughtsAloudApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '想唸 Thoughts Aloud',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    supportedLocales: const [
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
    ],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const LibraryPage(),
  );
}
