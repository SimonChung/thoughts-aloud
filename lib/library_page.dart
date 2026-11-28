import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';
import 'card_store.dart';
import 'l10n/l10n.dart';
import 'detail_page.dart';
import 'studio_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.store});
  final CardStore? store;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final library = CardLibrary(widget.store ?? CardStore());
  late Future<void> loading = library.load();
  final search = TextEditingController();
  final searchField = GlobalKey();
  bool savedOnly = false;
  bool searching = false;

  @override
  void dispose() {
    search.dispose();
    library.dispose();
    super.dispose();
  }

  void open(VoiceCard card) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DetailPage(card: card, library: library),
    ),
  );

  Future<void> record() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final card = await Navigator.of(context).push(
      MaterialPageRoute<VoiceCard>(
        builder: (_) => StudioPage(library: library),
      ),
    );
    if (!mounted || card == null) return;
    setState(() {
      savedOnly = false;
      searching = false;
      search.clear();
    });
    open(card);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, state) {
      if (state.connectionState != ConnectionState.done || state.hasError) {
        return Scaffold(
          body: Center(
            child: state.hasError
                ? TextButton(
                    onPressed: () => setState(() => loading = library.load()),
                    child: Text(context.l10n.retryLibrary),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      return libraryView(context);
    },
  );

  Widget libraryView(BuildContext context) => Scaffold(
    body: PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: pine,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 39,
                    height: 39,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [8.0, 17.0, 25.0, 14.0, 8.0]
                          .map(
                            (h) => Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.25,
                              ),
                              width: 3,
                              height: h,
                              decoration: BoxDecoration(
                                color: lime,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.appName, style: heading(26)),
                      if (context.l10n.brandSignature.isNotEmpty)
                        Text(
                          context.l10n.brandSignature,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: ink,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: searching
                      ? context.l10n.closeSearch
                      : context.l10n.searchCards,
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    searching = !searching;
                    if (!searching) search.clear();
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: library,
              builder: (context, _) {
                final cards = library
                    .search(search.text, context.l10n, savedOnly: savedOnly)
                    .toList();
                return PageSections(
                  leading: [_RecordingBanner(onStart: record)],
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  trailing: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.libraryTitle,
                            style: heading(23),
                          ),
                        ),
                        Text(
                          context.l10n.cardCount(library.count),
                          style: smallText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final saved in [false, true])
                          ChoiceChip(
                            label: Text(
                              saved
                                  ? context.l10n.savedCards
                                  : context.l10n.allCards,
                            ),
                            avatar: saved
                                ? Icon(
                                    Icons.bookmark_outline,
                                    size: 15,
                                    color: savedOnly ? paper : pine,
                                  )
                                : null,
                            selected: savedOnly == saved,
                            showCheckmark: false,
                            selectedColor: pine,
                            backgroundColor: paper,
                            side: BorderSide(
                              color: saved == savedOnly ? pine : line,
                            ),
                            shape: const StadiumBorder(),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: saved == savedOnly ? paper : pine,
                            ),
                            onSelected: (_) =>
                                setState(() => savedOnly = saved),
                          ),
                      ],
                    ),
                    if (searching)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextField(
                          key: searchField,
                          controller: search,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: context.l10n.searchHint,
                            border: const OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                    if (cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          search.text.trim().isNotEmpty
                              ? context.l10n.noMatches
                              : savedOnly
                              ? context.l10n.noBookmarks
                              : context.l10n.noCards,
                          style: prose,
                        ),
                      ),
                    for (final (index, card) in cards.indexed) ...[
                      if (index > 0) const Divider(height: 1, color: line),
                      CardTile(
                        card,
                        saved: library.isSaved(card),
                        onOpen: () => open(card),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(17),
    child: ColoredBox(
      color: const Color(0xff274f40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidth = MediaQuery.textScalerOf(context).scale(31) * 4.25;
          final tapeWidth = math.min(
            175.0,
            constraints.maxWidth - titleWidth - 14,
          );
          return Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: DotGrid())),
              if (tapeWidth > 70)
                Positioned(
                  right: -28,
                  bottom: 0,
                  child: Image.asset(
                    'assets/art/cassette.png',
                    width: tapeWidth,
                    excludeFromSemantics: true,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bannerTitle,
                      style: heading(31, color: paper),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.mic_none, size: 19),
                      label: Text(context.l10n.startRecording),
                      style: FilledButton.styleFrom(
                        backgroundColor: lime,
                        foregroundColor: ink,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
