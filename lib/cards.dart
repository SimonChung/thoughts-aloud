import 'package:flutter/foundation.dart';

enum Cover { sunset, ripple, steps, blush }

class VoiceCard {
  const VoiceCard(
    this.title,
    this.transcript,
    this.createdAt,
    this.seconds,
    this.topic,
    this.cover,
  );

  final String title;
  final String transcript;
  final DateTime createdAt;
  final int seconds;
  final String topic;
  final Cover cover;
}

class CardLibrary extends ChangeNotifier {
  final _cards = [
    VoiceCard(
      '把散步留在行事曆裡',
      '今天提早一站下車，慢慢走到公司。原來只要多出十分鐘，就能注意到路口那棵樹換了顏色。\n\n下週試著把散步也排進行事曆。',
      DateTime(2026, 11, 26, 9, 12),
      42,
      '生活',
      Cover.sunset,
    ),
    VoiceCard(
      '好點子需要一點空白',
      '有時候，最好的點子出現在什麼都沒做的時候。想替每天下午留一小段空白，看看會冒出什麼念頭。',
      DateTime(2026, 11, 25, 17, 35),
      68,
      '靈感',
      Cover.ripple,
    ),
    VoiceCard(
      '下次開會，先留三分鐘',
      '下次討論前，先讓每個人安靜寫三分鐘，再輪流說出想法。也許平常比較安靜的人會有更多空間。',
      DateTime(2026, 11, 24, 13, 40),
      36,
      '工作',
      Cover.steps,
    ),
    VoiceCard(
      '早晨的小小儀式',
      '水煮開以前，到陽台站一會兒。早上的第一件事，可以只是看著天慢慢亮起來。',
      DateTime(2026, 11, 23, 7, 48),
      54,
      '生活',
      Cover.blush,
    ),
  ];
  final _bookmarks = <VoiceCard>{};

  CardLibrary() {
    _bookmarks.add(_cards.firstWhere((card) => card.cover == Cover.ripple));
  }

  int get count => _cards.length;
  bool isSaved(VoiceCard card) => _bookmarks.contains(card);

  Iterable<VoiceCard> search(String query, {required bool savedOnly}) {
    final key = query.trim().toLowerCase();
    return _cards.where(
      (card) =>
          (!savedOnly || isSaved(card)) &&
          [
            card.title,
            card.transcript,
            card.topic,
          ].any((s) => s.toLowerCase().contains(key)),
    );
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
