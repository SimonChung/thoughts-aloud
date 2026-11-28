import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thoughts_aloud/card_store.dart';
import 'package:thoughts_aloud/cards.dart';
import 'package:thoughts_aloud/l10n/generated/app_localizations_en.dart';
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

  test('刪除會清除音檔、逐字稿與收藏，啟動時接續中斷的刪除並保留其他卡片', () async {
    final root = await Directory.systemTemp.createTemp();
    addTearDown(() => root.delete(recursive: true));
    final store = CardStore(directory: root);
    // This is the on-disk format used in 0.1.0.
    for (final id in ['remove', 'interrupted', 'keep']) {
      final dir = await Directory('${root.path}/$id').create();
      await File('${dir.path}/voice.wav').writeAsBytes([1, 2, 3]);
      await File('${dir.path}/card.json').writeAsString(
        '{"title":"$id","transcript":"words","createdAt":"2026-11-26T00:00:00Z","seconds":1,"audio":"voice.wav"}',
      );
      await store.bookmark(id, true);
    }
    final original = await store.load();
    await store.delete(original.cards.singleWhere((c) => c.id == 'remove'));
    expect(await Directory('${root.path}/remove').exists(), isFalse);
    expect(await Directory('${root.path}/deleted/remove').exists(), isFalse);
    await Directory('${root.path}/interrupted')
        .rename('${root.path}/deleted/interrupted');

    final library = CardLibrary(store);
    final strings = AppLocalizationsEn();
    await library.load();
    final sample = library
        .search('Good ideas', strings, savedOnly: true)
        .single;
    await store.bookmark(sample.id, true);
    await library.delete(sample);
    final reopened = CardLibrary(CardStore(directory: root));
    await reopened.load();
    expect(reopened.search('Good ideas', strings, savedOnly: false), isEmpty);
    expect(reopened.search('', strings, savedOnly: true).single.id, 'keep');
    final restored = await store.load();
    expect(restored.cards.single.id, 'keep');
    expect(restored.bookmarks, {'keep': true});
    expect(await File(restored.cards.single.audioPath).readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(
      await Directory('${root.path}/deleted/interrupted').exists(),
      isFalse,
    );
  });
}
