import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'cards.dart';
import 'l10n/l10n.dart';

const paper = Color(0xfff9f8f2);
const ink = Color(0xff20392f);
const muted = Color(0xff56645a);
const line = Color(0xffd9ddd1);
const pine = Color(0xff234c3d);
const lime = Color(0xffd5e699);
const smallText = TextStyle(fontSize: 13, color: muted, height: 1.5);
const prose = TextStyle(fontSize: 16, height: 1.8, color: ink);
const pagePadding = EdgeInsets.fromLTRB(22, 4, 22, 24);

TextStyle heading(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'Songti TC',
  fontFamilyFallback: const ['Noto Serif CJK TC', 'serif'],
  fontSize: size,
  fontWeight: FontWeight.w600,
  height: 1.3,
  color: color,
);

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: pine).copyWith(
    primary: pine,
    onPrimary: Colors.white,
    surface: paper,
    onSurface: ink,
    outline: muted,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    dividerColor: line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        side: const BorderSide(color: Color(0xffaebaaa)),
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, box) {
        final size = MediaQuery.sizeOf(context);
        final landscapeTablet =
            size.width > size.height &&
            size.shortestSide >= 600 &&
            box.maxWidth >= _twoColumnWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: landscapeTablet ? 1160 : 580),
            child: child,
          ),
        );
      },
    ),
  );
}

const double _twoColumnWidth = 740;

/// On a wide tablet each pane can scroll independently. A short, narrow window
/// keeps the actions in the scroll view so they cannot cover the content.
class PageSections extends StatelessWidget {
  const PageSections({
    super.key,
    required this.leading,
    required this.trailing,
    this.spacing = 24,
    this.actions,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
  });
  final List<Widget> leading, trailing;
  final double spacing;
  final Widget? actions;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final footer = actions;
      if (box.maxWidth >= _twoColumnWidth) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: ListView(
                  key: const PageStorageKey('leading-pane'),
                  primary: false,
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  keyboardDismissBehavior: keyboardDismissBehavior,
                  children: [
                    ...leading,
                    if (footer != null) ...[const SizedBox(height: 16), footer],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: ListView(
                  key: const PageStorageKey('trailing-pane'),
                  primary: false,
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  keyboardDismissBehavior: keyboardDismissBehavior,
                  children: trailing,
                ),
              ),
            ],
          ),
        );
      }
      final pinFooter = footer != null && box.maxHeight >= 320;
      final scroll = ListView(
        padding: pagePadding,
        keyboardDismissBehavior: keyboardDismissBehavior,
        children: [
          ...leading,
          SizedBox(height: spacing),
          ...trailing,
          if (footer != null && !pinFooter) footer,
        ],
      );
      return pinFooter
          ? Column(
              children: [
                Expanded(child: scroll),
                footer,
              ],
            )
          : scroll;
    },
  );
}

class PageBar extends StatelessWidget {
  const PageBar(this.title, {super.key, required this.onBack, this.trailing});
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    ),
  );
}

class CardTile extends StatelessWidget {
  const CardTile(
    this.card, {
    super.key,
    required this.saved,
    required this.onOpen,
    this.compact = false,
  });
  final VoiceCard card;
  final bool saved;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 13),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/art/${card.cover.name}-thumb.png',
              width: compact ? 37 : 50,
              height: compact ? 42 : 56,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.text(context.l10n).title,
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.cardSummary(
                        MaterialLocalizations.of(context)
                            .formatShortMonthDay(card.createdAt),
                        timecode(card.seconds),
                      ),
                      style: smallText,
                    ),
                    if (saved)
                      Icon(
                        Icons.bookmark,
                        size: 14,
                        color: muted,
                        semanticLabel: context.l10n.bookmarked,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 19, color: muted),
        ],
      ),
    ),
  );
}

class Waveform extends CustomPainter {
  const Waveform({this.phase = 4, this.progress = 0, this.studio = false});
  final double phase, progress;
  final bool studio;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final step = studio ? 4.4 : 3.4;
    final count = (size.width / step).floor();
    if (studio) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint..color = const Color(0xff657b66),
      );
    }
    for (var i = 0; i < count; i++) {
      final n = i + phase;
      final envelope =
          .24 + .76 * (math.sin(n * .106) * math.cos(n * .049)).abs();
      final peak = .13 + .87 * (math.sin(n * 1.77) * math.cos(n * .49)).abs();
      final height = math.max(2.0, size.height * envelope * peak);
      paint.color = studio
          ? lime
          : (i / count < progress ? pine : const Color(0xff879878));
      canvas.drawRect(
        Rect.fromLTWH(
          i * step,
          (size.height - height) / 2,
          studio ? 2.8 : 2,
          height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(Waveform oldDelegate) =>
      phase != oldDelegate.phase ||
      progress != oldDelegate.progress ||
      studio != oldDelegate.studio;
}

class DotGrid extends CustomPainter {
  const DotGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x20d5e699);
    for (double x = 3; x < size.width; x += 6) {
      for (double y = 3; y < size.height; y += 6) {
        canvas.drawCircle(Offset(x, y), .8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGrid oldDelegate) => false;
}
