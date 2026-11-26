import 'package:flutter/foundation.dart';

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
  const VoiceCard(this.createdAt, this.seconds, this.topic, this.cover);
  final DateTime createdAt;
  final int seconds;
  final Topic topic;
  final Cover cover;

  CardText text(AppLocalizations strings);
}

class RecordedCard extends VoiceCard {
  const RecordedCard(this.content, DateTime createdAt, int seconds)
    : super(createdAt, seconds, Topic.life, Cover.ripple);

  final CardText content;

  @override
  CardText text(AppLocalizations strings) => content;
}

class _SampleCard extends VoiceCard {
  const _SampleCard(
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
      (s) => (title: s.walkTitle, transcript: s.walkText),
      DateTime(2026, 11, 26, 9, 12),
      42,
      Topic.life,
      Cover.sunset,
    ),
    _SampleCard(
      (s) => (title: s.ideasTitle, transcript: s.ideasText),
      DateTime(2026, 11, 25, 17, 35),
      68,
      Topic.ideas,
      Cover.ripple,
    ),
    _SampleCard(
      (s) => (title: s.meetingTitle, transcript: s.meetingText),
      DateTime(2026, 11, 24, 13, 40),
      36,
      Topic.work,
      Cover.steps,
    ),
    _SampleCard(
      (s) => (title: s.morningTitle, transcript: s.morningText),
      DateTime(2026, 11, 23, 7, 48),
      54,
      Topic.life,
      Cover.blush,
    ),
  ];
  final _bookmarks = <VoiceCard>{};

  CardLibrary() {
    _bookmarks.add(_cards.firstWhere((card) => card.cover == Cover.ripple));
  }

  int get count => _cards.length;
  bool isSaved(VoiceCard card) => _bookmarks.contains(card);

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

  void toggleBookmark(VoiceCard card) {
    if (!_bookmarks.remove(card)) _bookmarks.add(card);
    notifyListeners();
  }

  void add(VoiceCard card) {
    _cards.insert(0, card);
    notifyListeners();
  }
}

String timecode(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
