import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:thoughts_aloud/l10n/l10n.dart';
import 'package:thoughts_aloud/main.dart';

Future<void> launch(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double scale = 1,
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
  await tester.pumpWidget(const ThoughtsAloudApp());
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('錄音能暫停、繼續、編輯並存回卡片匣', (tester) async {
    await launch(tester);
    expect(find.text('想唸'), findsOneWidget);
    await tap(tester, find.text('開始錄音'));
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('聽見有人在練琴'), findsOneWidget);
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
    expect(find.textContaining('聽見有人在練琴'), findsOneWidget);
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

  testWidgets('切換語言會更新錄音範例與驗證提示，保留使用者輸入', (tester) async {
    await launch(tester, locale: const Locale('en', 'GB'));
    await tap(tester, find.text('Start recording'));
    await tester.pump(const Duration(seconds: 7));
    expect(find.textContaining('practicing the piano'), findsOneWidget);
    await tap(tester, find.text('Pause'));
    await tap(tester, find.text('Finish recording'));
    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.first).controller!.text,
      'Piano around the corner',
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
      contains('聽見有人在練琴'),
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
