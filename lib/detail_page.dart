import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';
import 'voice_media.dart';
import 'l10n/l10n.dart';

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
  int positionMs = 0;
  bool pending = false;
  bool polling = false;
  bool deleting = false;
  int generation = 0;
  String? get audioPath => switch (widget.card) {
    RecordedCard(:final audioPath) => audioPath,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void pause() {
    generation++;
    final path = audioPath;
    if (path != null) {
      unawaited(voiceChannel.invokeMethod<void>('stopPlayer', {'path': path}));
    }
    timer?.cancel();
    timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (timer != null || pending)) {
      setState(pause);
    }
  }

  Future<void> togglePlay() async {
    if (pending) return;
    final path = audioPath;
    if (path == null) {
      togglePreview();
      return;
    }
    if (timer != null) {
      setState(pause);
      return;
    }
    final token = ++generation;
    setState(() => pending = true);
    try {
      if (position >= widget.card.seconds) {
        positionMs = 0;
        position = 0;
      }
      await voiceChannel.invokeMethod<void>('play', {
        'path': path,
        'position': positionMs,
      });
      if (!mounted || generation != token) return;
      setState(
        () => timer = Timer.periodic(
          const Duration(milliseconds: 180),
          (_) => refreshPlayer(path, token),
        ),
      );
    } catch (_) {
      if (mounted && generation == token) playbackError();
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  Future<void> refreshPlayer(String path, int token) async {
    if (polling) return;
    polling = true;
    try {
      final data = (await voiceChannel.invokeMapMethod<String, dynamic>(
        'player',
        {'path': path},
      ))!;
      if (!mounted || generation != token) return;
      setState(() {
        positionMs = data['position'] as int;
        position = (positionMs ~/ 1000).clamp(0, widget.card.seconds);
        if (data['playing'] != true) {
          if (data['completed'] == true) position = widget.card.seconds;
          pause();
        }
      });
    } catch (_) {
      if (mounted && generation == token) {
        setState(pause);
        playbackError();
      }
    } finally {
      polling = false;
    }
  }

  void playbackError() =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.playError)));

  Future<void> confirmDelete() async {
    setState(pause);
    final card = widget.card;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final strings = context.l10n;
        return AlertDialog(
          scrollable: true,
          title: Text(strings.deleteCardTitle(card.text(strings).title)),
          content: Text(
            card is RecordedCard
                ? strings.deleteRecordingMessage
                : strings.deleteSampleMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.cancelDelete),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(strings.deleteCard),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    setState(() => deleting = true);
    try {
      await widget.library.delete(card);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.deleteError)));
    }
  }

  void togglePreview() {
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
    final strings = context.l10n;
    final text = card.text(strings);
    final local = MaterialLocalizations.of(context);
    final page = ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final saved = library.isSaved(card);
        final related = library.related(card).toList();
        return Scaffold(
          body: PageBody(
            child: Column(
              children: [
                PageBar(
                  strings.voiceCard,
                  onBack: () => Navigator.pop(context),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: saved
                            ? strings.removeBookmark
                            : strings.addBookmark,
                        isSelected: saved,
                        icon: const Icon(Icons.bookmark_outline),
                        selectedIcon: const Icon(Icons.bookmark),
                        onPressed: library.saving(card)
                            ? null
                            : () async {
                                try {
                                  await library.toggleBookmark(card);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(strings.saveError),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                      IconButton(
                        tooltip: strings.deleteCard,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: library.saving(card) ? null : confirmDelete,
                      ),
                    ],
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
                      Text(text.title, style: heading(27)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            strings.cardMetadata(
                              local.formatShortDate(card.createdAt),
                              local.formatTimeOfDay(
                                TimeOfDay.fromDateTime(card.createdAt),
                                alwaysUse24HourFormat:
                                    MediaQuery.alwaysUse24HourFormatOf(context),
                              ),
                            ),
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
                            child: Text(
                              card.topic.label(strings),
                              style: smallText,
                            ),
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
                              onPressed: pending ? null : togglePlay,
                              tooltip: timer == null
                                  ? (audioPath == null
                                        ? strings.playDemo
                                        : strings.playAudio)
                                  : (audioPath == null
                                        ? strings.pauseDemo
                                        : strings.pauseAudio),
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
                                      Text(
                                        audioPath == null
                                            ? strings.playbackPreview
                                            : strings.recordedAudio,
                                        style: smallText,
                                      ),
                                      Text(
                                        strings.playbackTime(
                                          timecode(position),
                                          timecode(card.seconds),
                                        ),
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
                      Text(strings.transcript, style: heading(20)),
                      const SizedBox(height: 8),
                      Text(
                        text.transcript.isEmpty
                            ? strings.noTranscript
                            : text.transcript,
                        style: prose,
                      ),
                      const SizedBox(height: 20),
                      Text(strings.relatedCards, style: heading(20)),
                      const SizedBox(height: 6),
                      if (related.isEmpty)
                        Text(strings.noRelatedCards, style: smallText),
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
    return PopScope(
      canPop: !deleting,
      child: AbsorbPointer(absorbing: deleting, child: page),
    );
  }
}
