import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';
import 'l10n/l10n.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> with WidgetsBindingObserver {
  final title = TextEditingController();
  final transcript = TextEditingController();
  final form = GlobalKey<FormState>();
  final titleField = GlobalKey();
  final transcriptField = GlobalKey();
  Timer? timer;
  int seconds = 0;
  bool editing = false;
  bool editedTranscript = false;
  bool editedTitle = false;
  AppLocalizations? draftLanguage;
  bool confirming = false;
  bool leaving = false;
  bool showValidation = false;

  String get words => context.l10n.demoTranscript(switch (seconds ~/ 6) {
    0 => 'opening',
    1 => 'piano',
    2 => 'sounds',
    _ => 'complete',
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = context.l10n;
    if (draftLanguage == strings) return;
    draftLanguage = strings;
    if (!editedTitle) title.text = strings.demoTitle;
    if (editing && !editedTranscript) transcript.text = words;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  void start() {
    final offset = seconds;
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => setState(() => seconds = offset + timer.tick),
    );
  }

  void pause() {
    timer?.cancel();
    timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && timer != null) setState(pause);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pause();
    title.dispose();
    transcript.dispose();
    super.dispose();
  }

  void finish() {
    setState(() {
      pause();
      if (!editedTranscript) transcript.text = words;
      editing = true;
    });
  }

  void save() {
    if (leaving) return;
    if (!form.currentState!.validate()) {
      setState(() => showValidation = true);
      return;
    }
    leaving = true;
    final card = RecordedCard(
      (title: title.text.trim(), transcript: transcript.text.trim()),
      DateTime.now(),
      math.max(1, seconds),
    );
    Navigator.pop(context, card);
  }

  Future<void> back() async {
    if (confirming || leaving) return;
    if (editing) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => editing = false);
      return;
    }
    confirming = true;
    final wasRunning = timer != null;
    setState(pause);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(dialogContext.l10n.leaveTitle),
        content: Text(dialogContext.l10n.leaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.discardRecording),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.keepRecording),
          ),
        ],
      ),
    );
    if (!mounted) return;
    confirming = false;
    if (discard == true) {
      leaving = true;
      Navigator.pop(context);
    } else if (wasRunning &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      setState(start);
    }
  }

  Widget controls() {
    final toggle = OutlinedButton.icon(
      onPressed: () => setState(timer == null ? start : pause),
      icon: Icon(timer == null ? Icons.mic_none : Icons.pause, size: 18),
      label: Text(timer == null ? context.l10n.resume : context.l10n.pause),
    );
    final done = FilledButton.icon(
      onPressed: finish,
      icon: const Icon(Icons.stop, size: 18),
      label: Text(context.l10n.finishRecording),
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < MediaQuery.textScalerOf(context).scale(14) * 16) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [toggle, const SizedBox(height: 8), done],
            );
          }
          return Row(
            children: [
              Expanded(child: toggle),
              const SizedBox(width: 10),
              Expanded(child: done),
            ],
          );
        },
      ),
    );
  }

  Widget monitor() => PageSections(
    actions: controls(),
    leading: [
      Text(context.l10n.studioTitle, style: heading(32)),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ColoredBox(
          color: const Color(0xff203d32),
          child: CustomPaint(
            painter: const DotGrid(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: DefaultTextStyle(
                style: const TextStyle(color: paper, fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: timer == null
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                                color: timer == null
                                    ? lime
                                    : const Color(0xffefa27f),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              timer == null
                                  ? context.l10n.paused
                                  : context.l10n.recording,
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xff7f9684)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(context.l10n.demoMode),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timecode(seconds),
                        style: const TextStyle(
                          fontSize: 60,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                          color: paper,
                          letterSpacing: -3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 76,
                      child: CustomPaint(
                        painter: Waveform(
                          studio: true,
                          phase: MediaQuery.disableAnimationsOf(context)
                              ? 8
                              : seconds * 1.7,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xff80927d)),
                    const SizedBox(height: 5),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 4,
                      children: [
                        Text(context.l10n.secondsAgo(6)),
                        Text(context.l10n.secondsAgo(3)),
                        Text(context.l10n.now),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
    trailing: [
      Row(
        children: [
          Expanded(
            child: Text(context.l10n.liveTranscript, style: heading(23)),
          ),
          const Icon(Icons.notes, size: 18, color: muted),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: Color(0xffa3b48c), width: 3),
          ),
        ),
        padding: const EdgeInsetsDirectional.only(start: 14),
        child: Text(words, style: prose),
      ),
      const SizedBox(height: 16),
      Text(context.l10n.demoNote, style: smallText),
    ],
  );

  Widget editor() => Form(
    key: form,
    autovalidateMode: showValidation
        ? AutovalidateMode.always
        : AutovalidateMode.disabled,
    child: PageSections(
      spacing: 16,
      leading: [
        Text(context.l10n.editCard, style: heading(32)),
        const SizedBox(height: 8),
        Text(context.l10n.demoDuration(timecode(seconds)), style: smallText),
        const SizedBox(height: 24),
        TextFormField(
          key: titleField,
          controller: title,
          onChanged: (_) => editedTitle = true,
          maxLength: 100,
          decoration: InputDecoration(
            labelText: context.l10n.cardTitle,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          validator: (s) =>
              (s ?? '').trim().isEmpty ? context.l10n.missingTitle : null,
        ),
      ],
      trailing: [
        TextFormField(
          key: transcriptField,
          controller: transcript,
          minLines: 5,
          maxLines: null,
          style: prose,
          onChanged: (_) => editedTranscript = true,
          decoration: InputDecoration(
            labelText: context.l10n.transcript,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          validator: (s) =>
              (s ?? '').trim().isEmpty ? context.l10n.missingTranscript : null,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.check),
          label: Text(context.l10n.saveCard),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<VoiceCard>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: Scaffold(
      body: PageBody(
        child: Column(
          children: [
            PageBar(
              editing ? context.l10n.studioTitle : context.l10n.voiceCard,
              onBack: back,
            ),
            Expanded(child: editing ? editor() : monitor()),
          ],
        ),
      ),
    ),
  );
}
