import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';
import 'voice_media.dart';
import 'l10n/l10n.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({super.key, required this.library});
  final CardLibrary library;
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
  VoiceDraft? draft;
  CaptureState? state;
  final levels = <double>[];
  bool editing = false;
  bool editedTranscript = false;
  bool proposedTitle = false;
  bool confirming = false;
  bool leaving = false;
  bool busy = true;
  bool polling = false;
  bool sealed = false;
  bool showValidation = false;
  bool backgrounded = false;
  String? problem;
  bool preparingSpeech = false;
  String? recordingLocale;

  int get seconds => (state?.milliseconds ?? 0) ~/ 1000;
  bool get running => state?.running ?? false;
  String get words => state?.text ?? '';
  String get locale =>
      Localizations.localeOf(context).languageCode == 'zh' ? 'zh-TW' : 'en-US';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) begin();
    });
  }

  Future<void> begin() async {
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      final allowed = await voiceChannel.invokeMethod<bool>('access', {
        'locale': locale,
      });
      if (!mounted) return;
      if (allowed != true) {
        setState(() => problem = 'permission');
        return;
      }
      recordingLocale = locale;
      if (defaultTargetPlatform == TargetPlatform.android) {
        setState(() => preparingSpeech = true);
        try {
          recordingLocale = await voiceChannel.invokeMethod<String>(
            'prepareSpeech',
            {'locale': recordingLocale},
          );
        } catch (_) {
          recordingLocale = null;
        } finally {
          if (mounted) setState(() => preparingSpeech = false);
        }
        if (!mounted || leaving) return;
      }
      draft ??= await VoiceDraft.create();
      if (!mounted) {
        await draft?.discard();
        return;
      }
      timer ??= Timer.periodic(
        const Duration(milliseconds: 180),
        (_) => poll(),
      );
      if (!backgrounded) {
        await updateCapture('start');
        if (mounted && running && backgrounded) await updateCapture('pause');
      }
    } catch (_) {
      if (mounted) setState(() => problem = 'capture');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void apply(CaptureState next) {
    state = next;
    if (next.failed) problem = 'capture';
    if (editing && !editedTranscript && transcript.text != next.text) {
      transcript.text = next.text;
    }
  }

  Future<void> poll() async {
    if (!mounted ||
        busy ||
        polling ||
        sealed ||
        draft == null ||
        leaving ||
        (!running && state?.transcribing != true)) {
      return;
    }
    polling = true;
    try {
      final next = await capture('status', draft!);
      if (!mounted || busy || sealed || leaving) return;
      setState(() {
        apply(next);
        if (next.running) {
          levels.add(next.level);
          if (levels.length > 34) levels.removeAt(0);
        }
      });
    } catch (_) {
      if (mounted) setState(() => problem = 'capture');
    } finally {
      polling = false;
    }
  }

  Future<void> updateCapture(String method) async {
    final next = await capture(method, draft!, locale: recordingLocale);
    if (mounted) setState(() => apply(next));
  }

  Future<void> transport(String action) async {
    if (busy || sealed || draft == null) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      await updateCapture(action);
      if (mounted && backgrounded && running) await updateCapture('pause');
    } catch (_) {
      if (mounted) setState(() => problem = 'capture');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) backgrounded = false;
    if (value == AppLifecycleState.hidden ||
        value == AppLifecycleState.paused) {
      backgrounded = true;
      if (running) unawaited(transport('pause'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    final abandoned = draft;
    if (abandoned != null && !leaving) unawaited(abandoned.discard());
    title.dispose();
    transcript.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (running) await transport('pause');
    if (!mounted || running || (state?.milliseconds ?? 0) == 0) return;
    setState(() {
      if (!proposedTitle) {
        final firstLine = words.trim().split('\n').first;
        title.text = firstLine.isEmpty
            ? context.l10n.voiceCard
            : firstLine.characters.take(60).toString();
        proposedTitle = true;
      }
      if (!editedTranscript) transcript.text = words;
      editing = true;
    });
  }

  Future<void> save() async {
    if (leaving || busy) return;
    if (!form.currentState!.validate()) {
      setState(() => showValidation = true);
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      if (!sealed) {
        await updateCapture('finish');
        sealed = true;
      }
      final card = await widget.library.save(draft!, (
        title: title.text.trim(),
        transcript: transcript.text.trim(),
      ), math.max(1, ((state?.milliseconds ?? 0) / 1000).ceil()));
      leaving = true;
      if (mounted) Navigator.pop(context, card);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> back() async {
    if (preparingSpeech && !leaving) {
      leaving = true;
      unawaited(voiceChannel.invokeMethod<void>('skipSpeechSetup'));
      Navigator.pop(context);
      return;
    }
    if (confirming || leaving || busy) return;
    if (draft == null) {
      Navigator.pop(context);
      return;
    }
    if (editing && !sealed) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => editing = false);
      return;
    }
    confirming = true;
    final wasRunning = running;
    if (running) await transport('pause');
    if (!mounted) return;
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
      try {
        await draft!.discard();
        leaving = true;
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) setState(() => problem = 'capture');
      }
    } else if (wasRunning &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await transport('start');
    }
  }

  Widget controls() {
    final toggle = OutlinedButton.icon(
      onPressed: preparingSpeech
          ? () => voiceChannel.invokeMethod<void>('skipSpeechSetup')
          : busy
          ? null
          : draft == null
          ? begin
          : () => transport(running ? 'pause' : 'start'),
      icon: Icon(!running ? Icons.mic_none : Icons.pause, size: 18),
      label: Text(
        preparingSpeech
            ? context.l10n.recordWithoutTranscript
            : draft == null
            ? context.l10n.retry
            : !running
            ? context.l10n.resume
            : context.l10n.pause,
      ),
    );
    final done = FilledButton.icon(
      onPressed: busy || (state?.milliseconds ?? 0) == 0 ? null : finish,
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
                                shape: !running
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                                color: !running
                                    ? lime
                                    : const Color(0xffefa27f),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              state == null
                                  ? context.l10n.ready
                                  : !running
                                  ? context.l10n.paused
                                  : context.l10n.recording,
                            ),
                          ],
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
                          levels: List.of(levels),
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
        child: Text(
          preparingSpeech
              ? context.l10n.preparingSpeech
              : words.isNotEmpty
              ? words
              : (state?.transcribing == true
                    ? context.l10n.listening
                    : context.l10n.manualTranscript),
          style: prose,
        ),
      ),
      const SizedBox(height: 16),
      if (problem != null)
        Text(
          problem == 'permission'
              ? context.l10n.microphoneDenied
              : context.l10n.captureError,
          style: smallText,
        )
      else if (words.isNotEmpty && running && state?.transcribing == false)
        Text(context.l10n.manualTranscript, style: smallText),
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
        Text(
          context.l10n.recordedDuration(timecode(seconds)),
          style: smallText,
        ),
        const SizedBox(height: 24),
        TextFormField(
          key: titleField,
          controller: title,
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
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : save,
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
