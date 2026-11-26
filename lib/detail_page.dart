import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.card, required this.library});
  final VoiceCard card;
  final CardLibrary library;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with WidgetsBindingObserver {
  Timer? timer;
  int position = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void pause() {
    timer?.cancel();
    timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && timer != null) setState(pause);
  }

  void togglePlay() {
    setState(() {
      if (timer != null) {
        pause();
        return;
      }
      if (position >= widget.card.seconds) position = 0;
      final start = position;
      timer = Timer.periodic(const Duration(seconds: 1), (tick) {
        setState(() {
          position = (start + tick.tick).clamp(0, widget.card.seconds);
          if (position >= widget.card.seconds) pause();
        });
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final library = widget.library;
    final local = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final saved = library.isSaved(card);
        final related = library.related(card).toList();
        return Scaffold(
          body: PageBody(
            child: Column(
              children: [
                PageBar(
                  '語音卡片',
                  onBack: () => Navigator.pop(context),
                  trailing: IconButton(
                    tooltip: saved ? '取消收藏' : '加入收藏',
                    isSelected: saved,
                    icon: const Icon(Icons.bookmark_outline),
                    selectedIcon: const Icon(Icons.bookmark),
                    onPressed: () => library.toggleBookmark(card),
                  ),
                ),
                Expanded(
                  child: PageSections(
                    spacing: 20,
                    leading: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/art/${card.cover.name}-cover.png',
                          height: 108,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(card.title, style: heading(27)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${local.formatShortDate(card.createdAt)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(card.createdAt), alwaysUse24HourFormat: true)}',
                            style: smallText,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: line),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(card.topic, style: smallText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffedf0e3),
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton.filled(
                              onPressed: togglePlay,
                              tooltip: timer == null ? '播放進度示範' : '暫停播放示範',
                              icon: Icon(
                                timer == null ? Icons.play_arrow : Icons.pause,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 30,
                                    child: CustomPaint(
                                      painter: Waveform(
                                        progress: position / card.seconds,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 4,
                                    children: [
                                      const Text('播放進度示範', style: smallText),
                                      Text(
                                        '${timecode(position)} / ${timecode(card.seconds)}',
                                        style: smallText,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    trailing: [
                      Text('逐字稿', style: heading(20)),
                      const SizedBox(height: 8),
                      Text(card.transcript, style: prose),
                      const SizedBox(height: 20),
                      Text('相關卡片', style: heading(20)),
                      const SizedBox(height: 6),
                      if (related.isEmpty)
                        const Text('目前沒有相同主題的卡片。', style: smallText),
                      for (final other in related)
                        CardTile(
                          other,
                          saved: library.isSaved(other),
                          compact: true,
                          onOpen: () {
                            setState(pause);
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DetailPage(card: other, library: library),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
