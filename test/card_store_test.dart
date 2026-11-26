import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thoughts_aloud/card_store.dart';
import 'package:thoughts_aloud/voice_media.dart';

void main() {
  test('重新開啟卡片匣保留錄音、原文、排序與收藏；失敗的錄音不會入匣', () async {
    final sandbox = await Directory.systemTemp.createTemp();
    addTearDown(() => sandbox.delete(recursive: true));
    final root = await Directory('${sandbox.path}/library').create();
    final store = CardStore(directory: root);
    final date = DateTime.utc(2026, 11, 26);
    for (final id in ['a', 'b', 'empty']) {
      final dir = await Directory('${sandbox.path}/drafts/$id')
          .create(recursive: true);
      final file = await File('${dir.path}/voice.wav')
          .writeAsBytes(id == 'empty' ? [] : [1, 2, 3]);
      final save = store.save(
        VoiceDraft(id, file.path),
        (title: id, transcript: '原文'),
        id == 'a' ? date : date.add(const Duration(hours: 1)),
        5,
      );
      if (id == 'empty') {
        await expectLater(save, throwsFormatException);
      } else {
        await save;
        expect(await dir.exists(), isFalse);
      }
    }
    await Future.wait([
      store.bookmark('sample-ideas', false),
      store.bookmark('a', true),
    ]);
    final restored = await CardStore(directory: root).load();
    expect(restored.cards.map((c) => c.id), ['b', 'a']);
    expect(restored.cards.last.content.transcript, '原文');
    expect(await File(restored.cards.last.audioPath).readAsBytes(), [1, 2, 3]);
    expect(restored.bookmarks, {'sample-ideas': false, 'a': true});
  });
}
