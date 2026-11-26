import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'card_store.dart';
import 'l10n/l10n.dart';
import 'library_page.dart';

void main() => runApp(const ThoughtsAloudApp());

class ThoughtsAloudApp extends StatelessWidget {
  const ThoughtsAloudApp({super.key, this.store});
  final CardStore? store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appName,
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    supportedLocales: const [
      Locale('en'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: LibraryPage(store: store),
  );
}
