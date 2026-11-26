import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'appearance.dart';
import 'cards.dart';

const _sample = ['剛才走過巷口的時候，', '聽見有人在練琴。', '有些日常的小聲音，', '也值得專程停下來聽。'];

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> with WidgetsBindingObserver {
  final title = TextEditingController(text: '巷口的琴聲');
  final transcript = TextEditingController();
  final form = GlobalKey<FormState>();
  final titleField = GlobalKey();
  final transcriptField = GlobalKey();
  Timer? timer;
  int seconds = 0;
  bool editing = false;
  bool editedTranscript = false;
  bool confirming = false;
  bool leaving = false;

  String get words => _sample.take(1 + seconds ~/ 6).join();

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
    if (leaving || !form.currentState!.validate()) return;
    leaving = true;
    final card = VoiceCard(
      title.text.trim(),
      transcript.text.trim(),
      DateTime.now(),
      math.max(1, seconds),
      '生活',
      Cover.ripple,
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
        title: const Text('離開這段錄音？'),
        content: const Text('這段示範錄音尚未存成卡片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('捨棄錄音'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留錄音'),
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
      label: Text(timer == null ? '繼續' : '暫停'),
    );
    final done = FilledButton.icon(
      onPressed: finish,
      icon: const Icon(Icons.stop, size: 18),
      label: const Text('完成錄音'),
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
      Text('錄音室', style: heading(32)),
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
                            Text(timer == null ? '已暫停' : '錄音中'),
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
                          child: const Text('示範模式'),
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
                    const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 4,
                      children: [Text('−6 s'), Text('−3 s'), Text('現在')],
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
          Expanded(child: Text('即時逐字稿', style: heading(23))),
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
      const Text('此處以範例文字示範錄音流程。', style: smallText),
    ],
  );

  Widget editor() => Form(
    key: form,
    child: PageSections(
      spacing: 16,
      leading: [
        Text('整理語音卡片', style: heading(32)),
        const SizedBox(height: 8),
        Text('示範錄音 · ${timecode(seconds)} · 僅保留在本次使用期間', style: smallText),
        const SizedBox(height: 24),
        TextFormField(
          key: titleField,
          controller: title,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '卡片標題',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          validator: (s) => (s ?? '').trim().isEmpty ? '請填寫卡片標題。' : null,
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
          decoration: const InputDecoration(
            labelText: '逐字稿',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          validator: (s) => (s ?? '').trim().isEmpty ? '請填寫逐字稿。' : null,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.check),
          label: const Text('儲存卡片'),
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
            PageBar(editing ? '錄音室' : '語音卡片', onBack: back),
            Expanded(child: editing ? editor() : monitor()),
          ],
        ),
      ),
    ),
  );
}
