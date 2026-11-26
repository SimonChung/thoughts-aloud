import 'package:flutter/foundation.dart';

import 'card_store.dart';
import 'voice_media.dart';
import 'l10n/generated/app_localizations.dart';

enum Cover { sunset, ripple, steps, blush }

enum Topic {
  life,
  ideas,
  work;

  String label(AppLocalizations strings) => switch (this) {
    life => strings.topicLife,
    ideas => strings.topicIdeas,
    work => strings.topicWork,
  };
}

typedef CardText = ({String title, String transcript});

sealed class VoiceCard {
  const VoiceCard(
    this.id,
    this.createdAt,
    this.seconds,
    this.topic,
    this.cover,
  );
  final String id;
  final DateTime createdAt;
  final int seconds;
  final Topic topic;
  final Cover cover;

  CardText text(AppLocalizations strings);
}

class RecordedCard extends VoiceCard {
  const RecordedCard(
    String id,
    this.content,
    DateTime createdAt,
    int seconds,
    this.audioPath,
  ) : super(id, createdAt, seconds, Topic.life, Cover.ripple);

  final String audioPath;
  final CardText content;

  @override
  CardText text(AppLocalizations strings) => content;
}

class _SampleCard extends VoiceCard {
  const _SampleCard(
    super.id,
    this.translation,
    super.createdAt,
    super.seconds,
    super.topic,
    super.cover,
  );
  final CardText Function(AppLocalizations) translation;

  @override
  CardText text(AppLocalizations strings) => translation(strings);
}

class CardLibrary extends ChangeNotifier {
  final _cards = <VoiceCard>[
    _SampleCard(
      'sample-walk',
      (s) => (title: s.walkTitle, transcript: s.walkText),
      DateTime(2026, 11, 26, 9, 12),
      42,
      Topic.life,
      Cover.sunset,
    ),
    _SampleCard(
      'sample-ideas',
      (s) => (title: s.ideasTitle, transcript: s.ideasText),
      DateTime(2026, 11, 25, 17, 35),
      68,
      Topic.ideas,
      Cover.ripple,
    ),
    _SampleCard(
      'sample-meeting',
      (s) => (title: s.meetingTitle, transcript: s.meetingText),
      DateTime(2026, 11, 24, 13, 40),
      36,
      Topic.work,
      Cover.steps,
    ),
    _SampleCard(
      'sample-morning',
      (s) => (title: s.morningTitle, transcript: s.morningText),
      DateTime(2026, 11, 23, 7, 48),
      54,
      Topic.life,
      Cover.blush,
    ),
  ];
  final CardStore store;
  final _bookmarks = <String>{'sample-ideas'};
  final _saving = <String>{};

  CardLibrary(this.store);

  Future<void> load() async {
    final data = await store.load();
    _cards.removeWhere((card) => card is RecordedCard);
    _cards.insertAll(0, data.cards);
    _bookmarks.clear();
    _bookmarks.add('sample-ideas');
    for (final entry in data.bookmarks.entries) {
      if (entry.value) {
        _bookmarks.add(entry.key);
      } else {
        _bookmarks.remove(entry.key);
      }
    }
  }

  int get count => _cards.length;
  bool isSaved(VoiceCard card) => _bookmarks.contains(card.id);
  bool saving(VoiceCard card) => _saving.contains(card.id);

  Iterable<VoiceCard> search(
    String query,
    AppLocalizations strings, {
    required bool savedOnly,
  }) {
    final key = query.trim().toLowerCase();
    return _cards.where((card) {
      if (savedOnly && !isSaved(card)) return false;
      if (key.isEmpty) return true;
      final text = card.text(strings);
      return [
        text.title,
        text.transcript,
        card.topic.label(strings),
      ].any((value) => value.toLowerCase().contains(key));
    });
  }

  Iterable<VoiceCard> related(VoiceCard card) => _cards
      .where((other) => other != card && other.topic == card.topic)
      .take(2);

  Future<void> toggleBookmark(VoiceCard card) async {
    if (!_saving.add(card.id)) return;
    final saved = !isSaved(card);
    notifyListeners();
    try {
      await store.bookmark(card.id, saved);
      if (saved) {
        _bookmarks.add(card.id);
      } else {
        _bookmarks.remove(card.id);
      }
    } finally {
      _saving.remove(card.id);
      notifyListeners();
    }
  }

  Future<RecordedCard> save(
    VoiceDraft draft,
    CardText content,
    int seconds,
  ) async {
    final card = await store.save(draft, content, DateTime.now(), seconds);
    _cards.insert(0, card);
    notifyListeners();
    return card;
  }
}

String timecode(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
