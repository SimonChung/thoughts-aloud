import 'package:flutter/services.dart';

/// One foreground recording or playback session owns the device audio hardware.
const voiceChannel = MethodChannel('io.github.simonchung.thoughts_aloud/voice');

class VoiceDraft {
  const VoiceDraft(this.id, this.path);
  final String id;
  final String path;

  static Future<VoiceDraft> create() async {
    final info = (await voiceChannel.invokeMapMethod<String, String>('draft'))!;
    return VoiceDraft(info['id']!, info['path']!);
  }

  Future<void> discard() =>
      voiceChannel.invokeMethod('discard', {'path': path});
}

typedef CaptureState = ({
  int milliseconds,
  bool running,
  double level,
  String text,
  bool transcribing,
  bool failed,
});

Future<CaptureState> capture(
  String method,
  VoiceDraft draft, {
  String? locale,
}) async {
  final data = (await voiceChannel.invokeMapMethod<String, dynamic>(method, {
    'path': draft.path,
    'locale': locale,
  }))!;
  return (
    milliseconds: data['milliseconds'] as int,
    running: data['running'] as bool,
    level: (data['level'] as num).toDouble(),
    text: data['text'] as String,
    transcribing: data['transcribing'] as bool,
    failed: data['failed'] == true,
  );
}
