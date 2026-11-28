import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:thoughts_aloud/l10n/l10n.dart';
import 'package:thoughts_aloud/main.dart';
import 'package:thoughts_aloud/cards.dart';
import 'package:thoughts_aloud/card_store.dart';
import 'package:thoughts_aloud/voice_media.dart';

class MemoryStore extends CardStore {
  final cards = <RecordedCard>[];
  final bookmarks = <String, bool>{};
  final deletedSamples = <String>{};
  bool failDelete = false;

  @override
  Future<LibraryContents> load() async =>
      (cards: cards, bookmarks: bookmarks, deletedSamples: deletedSamples);

  @override
  Future<void> delete(VoiceCard card) async {
    if (failDelete) throw StateError('Storage unavailable');
    if (card is RecordedCard) {
      cards.remove(card);
    } else {
      deletedSamples.add(card.id);
    }
    bookmarks.remove(card.id);
  }

  @override
  Future<void> bookmark(String id, bool saved) async => bookmarks[id] = saved;

  @override
  Future<RecordedCard> save(
    VoiceDraft draft,
    CardText text,
    DateTime date,
    int seconds,
  ) async {
    final card = RecordedCard(draft.id, text, date, seconds, draft.path);
    cards.add(card);
    return card;
  }
}

Future<void> launch(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double scale = 1,
  bool micAllowed = true,
  Completer<String?>? setup,
  List<String?>? recordingLocales,
  String recognized = '在窗邊聽見旋律。',
  List<String>? calls,
  MemoryStore? store,
  Locale locale = const Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  ),
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final clock = tester.binding.clock;
  DateTime? start;
  var recorded = Duration.zero;
  var playerPosition = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(voiceChannel, (
    call,
  ) async {
    calls?.add(call.method);
    switch (call.method) {
      case 'access':
        return micAllowed;
      case 'prepareSpeech':
        return setup != null
            ? await setup.future
            : (call.arguments['locale'] == 'zh-TW' ? 'cmn-Hant-TW' : 'en-US');
      case 'skipSpeechSetup':
        if (setup != null && !setup.isCompleted) setup.complete(null);
        return null;
      case 'draft':
        return {'id': 'test-id', 'path': '/draft/voice.wav'};
      case 'play':
        playerPosition = call.arguments['position'];
        return null;
      case 'player':
        return {'position': playerPosition += 200, 'playing': true};
      case 'discard':
      case 'stopPlayer':
        return null;
      case 'start':
        recordingLocales?.add(call.arguments['locale'] as String?);
        start ??= clock.now();
      case 'pause':
      case 'finish':
        if (start != null) recorded += clock.now().difference(start!);
        start = null;
      case 'status':
        break;
      default:
        throw StateError(call.method);
    }
    final elapsed =
        recorded +
        (start == null ? Duration.zero : clock.now().difference(start!));
    return {
      'milliseconds': elapsed.inMilliseconds,
      'running': start != null,
      'level': 0.3,
      'text': recognized,
      'transcribing': recognized.isNotEmpty && start != null,
    };
  });
  await tester.pumpWidget(ThoughtsAloudApp(store: store ?? MemoryStore()));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('刪除播放中的錄音卡可以取消、失敗可重試，成功後更新收藏與搜尋', (tester) async {
    final store = MemoryStore();
    final calls = <String>[];
    const title = '測試錄音卡';
    await store.save(
      VoiceDraft('recorded', '/recorded/voice.wav'),
      (title: title, transcript: '搜尋這段原音'),
      DateTime(2026),
      10,
    );
    await store.bookmark('recorded', true);
    await launch(tester, store: store, calls: calls);
    await tap(tester, find.widgetWithText(ChoiceChip, '收藏'));
    await tap(tester, find.byTooltip('搜尋卡片'));
    await tester.enterText(find.byType(TextField), '搜尋這段原音');
    await tester.pumpAndSettle();
    await tap(tester, find.text(title));
    await tap(tester, find.byTooltip('播放錄音'));
    await tap(tester, find.byTooltip('刪除卡片'));
    expect(find.text('刪除「$title」？'), findsOneWidget);
    expect(calls, containsAllInOrder(['play', 'stopPlayer']));
    await tap(tester, find.text('取消'));
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    store.failDelete = true;
    await tap(tester, find.byTooltip('刪除卡片'));
    await tap(tester, find.text('刪除卡片'));
    expect(find.text('未能刪除卡片，請再試一次。'), findsOneWidget);
    expect(store.cards, hasLength(1));
    store.failDelete = false;
    await tap(tester, find.byTooltip('刪除卡片'));
    await tap(tester, find.text('刪除卡片'));
    expect(find.text('4 張卡片'), findsOneWidget);
    expect(find.textContaining('找不到符合的卡片'), findsOneWidget);
    expect(store.cards, isEmpty);
    expect(store.bookmarks, isEmpty);
  });

  testWidgets('從相關卡片刪除範例後回到卡片匣，重開後仍保留刪除結果', (tester) async {
    final store = MemoryStore();
    await launch(tester, store: store);
    await tap(tester, find.text('把散步留在行事曆裡'));
    await tap(tester, find.text('早晨的小小儀式'));
    await tap(tester, find.text('把散步留在行事曆裡'));
    await tap(tester, find.byTooltip('刪除卡片'));
    await tap(tester, find.text('刪除卡片'));
    expect(find.text('3 張卡片'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester, store: store, locale: const Locale('en'));
    expect(find.text('3 cards'), findsOneWidget);
    expect(find.text('Put a walk on the calendar'), findsNothing);
    for (final title in [
      'Good ideas need a little space',
      'Give the next meeting three minutes',
      'A small morning ritual',
    ]) {
      await tap(tester, find.text(title));
      await tap(tester, find.byTooltip('Delete card'));
      await tap(tester, find.text('Delete card'));
    }
    expect(find.text('0 cards'), findsOneWidget);
    expect(find.textContaining('Your card box is empty'), findsOneWidget);
  });

  testWidgets('錄音能暫停、繼續、編輯並存回卡片匣', (tester) async {
    final calls = <String>[];
    await launch(tester, calls: calls);
    expect(find.text('想唸'), findsOneWidget);
    await tap(tester, find.text('開始錄音'));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('在窗邊聽見旋律。'), findsOneWidget);
    await tap(tester, find.text('暫停'));
    final clock = tester
        .widget<Text>(find.textContaining(RegExp(r'^\d+:\d+$')))
        .data!;
    await tester.pump(const Duration(seconds: 8));
    expect(find.text(clock), findsOneWidget);
    await tap(tester, find.text('繼續'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(clock), findsNothing);
    await tap(tester, find.text('完成錄音'));
    await tester.enterText(find.byType(TextFormField).first, ' ');
    await tap(tester, find.text('儲存卡片'));
    expect(find.text('請填寫卡片標題。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '巷口的聲音');
    await tester.enterText(find.byType(TextFormField).last, '在窗邊聽見一段旋律。');
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.text('完成錄音'));
    await tap(tester, find.text('儲存卡片'));
    expect(find.text('巷口的聲音'), findsOneWidget);
    expect(find.text('在窗邊聽見一段旋律。'), findsOneWidget);
    await tap(tester, find.byTooltip('播放錄音'));
    await tester.pump(const Duration(seconds: 1));
    await tap(tester, find.byTooltip('暫停播放'));
    expect(
      calls,
      containsAllInOrder([
        'start',
        'pause',
        'start',
        'pause',
        'finish',
        'play',
        'player',
        'stopPlayer',
      ]),
    );
    await tap(tester, find.byTooltip('加入收藏'));
    await tap(tester, find.byTooltip('返回'));
    expect(find.text('5 張卡片'), findsOneWidget);
    await tap(tester, find.widgetWithText(ChoiceChip, '收藏'));
    expect(find.text('巷口的聲音'), findsOneWidget);
    await tap(tester, find.byTooltip('搜尋卡片'));
    await tester.enterText(find.byType(TextField), '旋律');
    await tester.pumpAndSettle();
    expect(find.text('巷口的聲音'), findsOneWidget);
    expect(find.text('好點子需要一點空白'), findsNothing);
    await tester.enterText(find.byType(TextField), '找不到這段文字');
    await tester.pumpAndSettle();
    expect(find.textContaining('找不到符合的卡片'), findsOneWidget);
  });

  testWidgets('繁中錄音使用裝置模型標籤，下載期間也可直接只錄音', (tester) async {
    final locales = <String?>[];
    await launch(tester, recordingLocales: locales);
    await tap(tester, find.text('開始錄音'));
    expect(locales, ['cmn-Hant-TW']);
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.text('捨棄錄音'));
    await launch(
      tester,
      setup: Completer<String?>(),
      recordingLocales: locales,
    );
    await tap(tester, find.text('開始錄音'));
    expect(find.textContaining('可能需要下載模型'), findsOneWidget);
    expect(locales.length, 1);
    await tap(tester, find.text('先只錄音'));
    expect(locales, ['cmn-Hant-TW', null]);
    expect(find.text('錄音中'), findsOneWidget);
  });

  testWidgets('詳情可播放到結尾、重播及往返相關卡片', (tester) async {
    await launch(tester);
    await tap(tester, find.text('把散步留在行事曆裡'));
    await tap(tester, find.byTooltip('播放進度示範'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02 / 00:42'), findsOneWidget);
    await tap(tester, find.byTooltip('暫停播放示範'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:02 / 00:42'), findsOneWidget);
    await tap(tester, find.byTooltip('播放進度示範'));
    await tester.pump(const Duration(seconds: 40));
    expect(find.text('00:42 / 00:42'), findsOneWidget);
    await tap(tester, find.byTooltip('播放進度示範'));
    expect(find.text('00:00 / 00:42'), findsOneWidget);
    await tap(tester, find.text('早晨的小小儀式'));
    await tap(tester, find.byTooltip('加入收藏'));
    await tap(tester, find.byTooltip('返回'));
    expect(find.text('00:00 / 00:42'), findsOneWidget);
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.widgetWithText(ChoiceChip, '收藏'));
    expect(find.text('早晨的小小儀式'), findsOneWidget);
    expect(find.text('把散步留在行事曆裡'), findsNothing);
  });

  testWidgets('平板橫式把操作與內容並排，旋轉保留搜尋、錄音與編輯內容', (tester) async {
    const portrait = Size(601, 1006);
    const landscape = Size(1006, 601);
    Future<void> rotate(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    await launch(tester, size: landscape);
    expect(
      tester.getTopRight(find.text('開始錄音')).dx,
      lessThan(tester.getTopLeft(find.text('我的卡片匣')).dx),
    );
    await tap(tester, find.byTooltip('搜尋卡片'));
    await tester.enterText(find.byType(TextField), '散步');
    await rotate(portrait);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '散步',
    );
    expect(find.text('好點子需要一點空白'), findsNothing);
    await tap(tester, find.byTooltip('關閉搜尋'));
    await tap(tester, find.text('開始錄音'));
    await tester.pump(const Duration(seconds: 7));
    await rotate(landscape);
    expect(
      tester.getTopRight(find.text('錄音室')).dx,
      lessThan(tester.getTopLeft(find.text('即時逐字稿')).dx),
    );
    expect(find.text('在窗邊聽見旋律。'), findsOneWidget);
    await tap(tester, find.text('完成錄音'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '橫放的平板');
    await tester.enterText(fields.last, '旋轉後繼續編輯。');
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    await tester.pumpAndSettle();
    expect(
      tester.getTopRight(fields.first).dx,
      lessThan(tester.getTopLeft(fields.last).dx),
    );
    await rotate(portrait);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).last)
          .controller
          .text,
      '旋轉後繼續編輯。',
    );
    tester.view.resetViewInsets();
    await rotate(landscape);
    await tap(tester, find.text('儲存卡片'));
    expect(find.text('旋轉後繼續編輯。'), findsOneWidget);
    expect(
      tester.getTopRight(find.text('橫放的平板')).dx,
      lessThan(tester.getTopLeft(find.text('逐字稿')).dx),
    );
    await rotate(portrait);
    expect(
      tester.getBottomLeft(find.text('橫放的平板')).dy,
      lessThan(tester.getTopLeft(find.text('逐字稿')).dy),
    );
    await tap(tester, find.byTooltip('返回'));
    expect(find.text('5 張卡片'), findsOneWidget);
  });

  testWidgets('英文回退、複數與語言偏好會套用到範例卡片及收藏', (tester) async {
    await launch(
      tester,
      locale: const Locale('fr', 'FR'),
      size: const Size(1006, 601),
    );
    expect(find.text('My cards'), findsOneWidget);
    final strings = tester.element(find.text('My cards')).l10n;
    expect(
      [strings.cardCount(0), strings.cardCount(1), strings.cardCount(4)],
      ['0 cards', '1 card', '4 cards'],
    );
    await tap(tester, find.byTooltip('Search cards'));
    await tester.enterText(find.byType(TextField), 'Everyday life');
    await tester.pumpAndSettle();
    expect(find.text('Put a walk on the calendar'), findsOneWidget);
    expect(find.text('Good ideas need a little space'), findsNothing);
    await tap(tester, find.byTooltip('Close search'));
    await tap(tester, find.text('Put a walk on the calendar'));
    await tap(tester, find.byTooltip('Add bookmark'));
    expect(find.text('A small morning ritual'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = [
      const Locale('fr'),
      const Locale('zh', 'TW'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('把散步留在行事曆裡'), findsOneWidget);
    expect(find.text('早晨的小小儀式'), findsOneWidget);
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.widgetWithText(ChoiceChip, '收藏'));
    expect(find.text('把散步留在行事曆裡'), findsOneWidget);
    expect(find.text('早晨的小小儀式'), findsNothing);
  });

  testWidgets('切換語言會更新驗證提示，保留辨識原文與使用者輸入', (tester) async {
    await launch(
      tester,
      locale: const Locale('en', 'GB'),
      recognized: 'I heard a piano.',
    );
    await tap(tester, find.text('Start recording'));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('I heard a piano.'), findsOneWidget);
    await tap(tester, find.text('Pause'));
    await tap(tester, find.text('Finish recording'));
    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      'I heard a piano.',
    );
    await tester.enterText(fields.first, '');
    await tap(tester, find.text('Save card'));
    expect(find.text('Enter a card title.'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = [const Locale('zh', 'HK')];
    await tester.pumpAndSettle();
    expect(find.text('請填寫卡片標題。'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.last).controller!.text,
      'I heard a piano.',
    );
    await tester.enterText(fields.first, 'My 日記');
    await tester.enterText(fields.last, '第一段：Hello.');
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    await tester.pumpAndSettle();
    await tap(tester, find.text('Save card'));
    expect(find.text('My 日記'), findsOneWidget);
    expect(find.text('第一段：Hello.'), findsOneWidget);
    expect(find.text('Everyday life'), findsOneWidget);
    tester.platformDispatcher.localesTestValue = [const Locale('zh', 'TW')];
    await tester.pumpAndSettle();
    expect(find.text('My 日記'), findsOneWidget);
    expect(find.text('第一段：Hello.'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);
  });

  testWidgets('拒絕麥克風權限可返回，辨識離線時仍可單獨儲存錄音', (tester) async {
    final calls = <String>[];
    await launch(tester, micAllowed: false, calls: calls);
    await tap(tester, find.text('開始錄音'));
    expect(find.textContaining('麥克風權限'), findsOneWidget);
    expect(calls, isNot(contains('start')));
    await tap(tester, find.byTooltip('返回'));
    await launch(tester, recognized: '');
    await tap(tester, find.text('開始錄音'));
    await tester.pump(const Duration(seconds: 2));
    await tap(tester, find.text('完成錄音'));
    await tester.enterText(find.byType(TextFormField).first, '原音');
    await tap(tester, find.text('儲存卡片'));
    expect(find.text('這段錄音沒有逐字稿。'), findsOneWidget);
    expect(find.byTooltip('播放錄音'), findsOneWidget);
  });

  testWidgets('英文窄螢幕放大字級仍可操作錄音及返回對話框', (tester) async {
    await launch(
      tester,
      locale: const Locale('en'),
      size: const Size(320, 568),
      scale: 2,
    );
    await tap(tester, find.text('Start recording'));
    await tap(tester, find.text('Pause'));
    expect(find.text('Resume'), findsOneWidget);
    await tap(tester, find.byTooltip('Back'));
    expect(find.text('Leave this recording?'), findsOneWidget);
    await tap(tester, find.text('Discard recording'));
    expect(find.text('4 cards'), findsOneWidget);
  });

  testWidgets('窄螢幕與兩倍字級可操作，系統返回會詢問是否捨棄', (tester) async {
    await launch(tester, size: const Size(320, 568), scale: 2);
    await tap(tester, find.text('開始錄音'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tap(tester, find.text('保留錄音'));
    expect(find.text('錄音室'), findsOneWidget);
    await tap(tester, find.text('完成錄音'));
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.byTooltip('返回'));
    await tap(tester, find.text('捨棄錄音'));
    expect(find.text('4 張卡片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
