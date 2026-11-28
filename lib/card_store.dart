import 'dart:convert';
import 'dart:io';

import 'cards.dart';
import 'voice_media.dart';

typedef LibraryContents = ({
  List<RecordedCard> cards,
  Map<String, bool> bookmarks,
  Set<String> deletedSamples,
});

class CardStore {
  CardStore({Directory? directory}) : _root = directory;
  Directory? _root;

  Future<Directory> get root async => _root ??= Directory(
    (await voiceChannel.invokeMethod<String>('library'))!,
  );

  Future<LibraryContents> load() async {
    final directory = await root;
    final cards = <RecordedCard>[];
    final bookmarks = <String, bool>{};
    final deletedSamples = <String>{};
    final deleted = Directory('${directory.path}/deleted');
    final marks = Directory('${directory.path}/bookmarks');
    if (await deleted.exists()) {
      await for (final entry in deleted.list(followLinks: false)) {
        final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (entry is File) deletedSamples.add(id);
        await _cleanDeleted(entry, File('${marks.path}/$id'));
      }
    }
    await for (final entry in directory.list(followLinks: false)) {
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is Directory && id != 'bookmarks' && id != 'deleted') {
        final json = jsonDecode(
          await File('${entry.path}/card.json').readAsString(),
        );
        cards.add(
          RecordedCard(
            id,
            (title: json['title'], transcript: json['transcript']),
            DateTime.parse(json['createdAt']).toLocal(),
            json['seconds'],
            '${entry.path}/${json['audio']}',
          ),
        );
      }
    }
    if (await marks.exists()) {
      await for (final entry in marks.list(followLinks: false)) {
        if (entry is File && !entry.path.endsWith('.tmp')) {
          bookmarks[entry.uri.pathSegments.last] =
              await entry.readAsString() == '1';
        }
      }
    }
    cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (cards: cards, bookmarks: bookmarks, deletedSamples: deletedSamples);
  }

  Future<void> delete(VoiceCard card) async {
    final directory = await root;
    final deleted = await Directory('${directory.path}/deleted').create();
    final path = '${deleted.path}/${card.id}';
    // Renaming commits the removal before any audio or metadata is unlinked.
    // A marker file keeps a bundled sample hidden across launches.
    final entry = card is RecordedCard
        ? await Directory('${directory.path}/${card.id}').rename(path)
        : await File(path).create();
    await _cleanDeleted(entry, File('${directory.path}/bookmarks/${card.id}'));
  }

  Future<void> _cleanDeleted(FileSystemEntity entry, File bookmark) async {
    try {
      if (await bookmark.exists()) await bookmark.delete();
      if (entry is Directory) await entry.delete(recursive: true);
    } on FileSystemException {
      // The card is already out of the library. Retry cleanup on next load.
    }
  }

  Future<RecordedCard> save(
    VoiceDraft draft,
    CardText content,
    DateTime date,
    int seconds,
  ) async {
    final destination = Directory('${(await root).path}/${draft.id}');
    final audio = File(draft.path);
    if (await audio.length() == 0) {
      throw const FormatException('Empty recording');
    }
    final name = audio.uri.pathSegments.last;
    await File('${audio.parent.path}/card.json').writeAsString(
      jsonEncode({
        'title': content.title,
        'transcript': content.transcript,
        'createdAt': date.toUtc().toIso8601String(),
        'seconds': seconds,
        'audio': name,
      }),
      flush: true,
    );
    // Both directories live in the app sandbox on the same filesystem. The
    // library sees audio and metadata together only once the rename succeeds.
    await audio.parent.rename(destination.path);
    return RecordedCard(
      draft.id,
      content,
      date,
      seconds,
      '${destination.path}/$name',
    );
  }

  Future<void> bookmark(String id, bool saved) async {
    final dir = await Directory('${(await root).path}/bookmarks')
        .create(recursive: true);
    final staging = await dir.createTemp('.bookmark-');
    try {
      final tmp = await File('${staging.path}/value')
          .writeAsString(saved ? '1' : '0', flush: true);
      await tmp.rename('${dir.path}/$id');
    } finally {
      await staging.delete(recursive: true);
    }
  }
}
