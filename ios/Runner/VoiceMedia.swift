import AVFoundation
import Flutter
import Speech

final class VoiceMedia: NSObject, AVAudioPlayerDelegate {
  private let files = FileManager.default
  private let session = AVAudioSession.sharedInstance()
  private let engine = AVAudioEngine()
  private var audioFile: AVAudioFile?
  private var draftPath: String?
  private var tapped = false
  private let meterLock = NSLock()
  private var level = 0.0
  private var frames: Int64 = 0
  private var writeFailed = false
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var recognizer: SFSpeechRecognizer?
  private var transcript = [String]()
  private var partial = ""
  private var generation = 0
  private var player: AVAudioPlayer?
  private var playerCompleted = false
  private var playerPath: String?
  private var channel: FlutterMethodChannel
  private var interruption: NSObjectProtocol?
  private var background: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "io.github.simonchung.thoughts_aloud/voice", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
      object: nil, queue: .main) { [weak self] note in
      if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue {
        self?.suspend()
      }
    }
    background = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
      object: nil, queue: .main) { [weak self] _ in self?.suspend() }
  }

  deinit {
    if let interruption { NotificationCenter.default.removeObserver(interruption) }
    if let background { NotificationCenter.default.removeObserver(background) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let path = args["path"] as? String ?? ""
    let locale = args["locale"] as? String ?? Locale.current.identifier
    do {
      switch call.method {
      case "library":
        var root = try files.url(for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true).appendingPathComponent("voice-cards")
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        result(root.path)
      case "access":
        session.requestRecordPermission { allowed in
          DispatchQueue.main.async {
            guard allowed, SFSpeechRecognizer(locale: Locale(identifier: locale))?.supportsOnDeviceRecognition == true
            else { result(allowed); return }
            SFSpeechRecognizer.requestAuthorization { _ in DispatchQueue.main.async { result(true) } }
          }
        }
      case "draft":
        let id = UUID().uuidString.lowercased()
        let dir = files.temporaryDirectory.appendingPathComponent("voice-drafts").appendingPathComponent(id)
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        result(["id": id, "path": dir.appendingPathComponent("voice.caf").path])
      case "start":
        try start(path: path, locale: locale)
        result(state())
      case "status":
        if meter().failed { pause() }
        result(state())
      case "pause":
        pause()
        result(state())
      case "finish":
        pause()
        let snapshot = state()
        reset()
        result(snapshot)
      case "discard":
        if draftPath == path { reset() }
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        guard dir.deletingLastPathComponent().standardizedFileURL.path ==
                files.temporaryDirectory.appendingPathComponent("voice-drafts").standardizedFileURL.path
        else { throw CocoaError(.fileWriteInvalidFileName) }
        if files.fileExists(atPath: dir.path) { try files.removeItem(at: dir) }
        result(nil)
      case "play":
        stopPlayer()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        let audio = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        audio.delegate = self
        playerCompleted = false
        audio.currentTime = Double(args["position"] as? Int ?? 0) / 1000
        guard audio.play() else { throw CocoaError(.fileReadUnknown) }
        player = audio
        playerPath = path
        result(nil)
      case "player":
        guard let player, playerPath == path else { throw CocoaError(.fileReadNoSuchFile) }
        result(["playing": player.isPlaying, "completed": playerCompleted, "position": Int(player.currentTime * 1000)])
      case "stopPlayer":
        if playerPath == path { stopPlayer() }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      if call.method == "start" { pause() }
      if call.method == "play" { stopPlayer() }
      result(FlutterError(code: "media", message: error.localizedDescription, details: nil))
    }
  }

  private func start(path: String, locale: String) throws {
    if engine.isRunning { return }
    if draftPath != path { reset(); draftPath = path }
    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
    try session.setActive(true)
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.fileReadUnknown) }
    if audioFile == nil {
      audioFile = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: format.settings)
    }
    guard let file = audioFile, format == file.processingFormat else { throw CocoaError(.fileWriteUnknown) }
    startSpeech(locale)
    meterLock.lock()
    writeFailed = false
    meterLock.unlock()
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
      guard let self else { return }
      do {
        try file.write(from: buffer)
        self.meterLock.lock()
        let speech = self.request
        self.meterLock.unlock()
        speech?.append(buffer)
        let n = Int(buffer.frameLength)
        var peak: Float = 0
        if let data = buffer.floatChannelData?[0] {
          for i in stride(from: 0, to: n, by: 4) { peak = max(peak, abs(data[i])) }
        }
        self.meterLock.lock()
        self.frames += Int64(n)
        self.level = Double(peak)
        self.meterLock.unlock()
      } catch {
        self.meterLock.lock()
        self.writeFailed = true
        self.meterLock.unlock()
      }
    }
    tapped = true
    engine.prepare()
    try engine.start()
  }

  private func startSpeech(_ locale: String) {
    closeSpeech()
    guard SFSpeechRecognizer.authorizationStatus() == .authorized,
          let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
          recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { return }
    self.recognizer = recognizer
    let speech = SFSpeechAudioBufferRecognitionRequest()
    speech.shouldReportPartialResults = true
    speech.requiresOnDeviceRecognition = true
    meterLock.lock()
    request = speech
    meterLock.unlock()
    let token = generation
    task = recognizer.recognitionTask(with: speech) { [weak self] response, error in
      DispatchQueue.main.async {
        guard let self, self.generation == token else { return }
        if let response { self.partial = response.bestTranscription.formattedString }
        if response?.isFinal == true && self.engine.isRunning && error == nil {
          self.startSpeech(locale)
        } else if response?.isFinal == true || error != nil {
          self.closeSpeech()
        }
      }
    }
  }

  private func closeSpeech() {
    generation += 1
    if !partial.isEmpty { transcript.append(partial); partial = "" }
    task?.cancel()
    task = nil
    meterLock.lock()
    request = nil
    meterLock.unlock()
    recognizer = nil
  }

  private func meter() -> (frames: Int64, level: Double, failed: Bool) {
    meterLock.lock()
    defer { meterLock.unlock() }
    return (frames, level, writeFailed)
  }

  private func state() -> [String: Any] {
    let sample = meter()
    let rate = audioFile?.processingFormat.sampleRate ?? 1
    return ["running": engine.isRunning, "milliseconds": Int(Double(sample.frames) * 1000 / rate),
      "level": engine.isRunning ? sample.level : 0, "transcribing": task != nil,
      "text": (transcript + [partial]).filter { !$0.isEmpty }.joined(separator: " "), "failed": sample.failed]
  }

  private func pause() {
    guard tapped || engine.isRunning else { return }
    engine.stop()
    if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    request?.endAudio()
    try? session.setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func reset() {
    pause()
    closeSpeech()
    transcript.removeAll()
    audioFile = nil
    draftPath = nil
    meterLock.lock()
    frames = 0
    writeFailed = false
    level = 0
    meterLock.unlock()
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if self.player === player { playerCompleted = flag }
  }

  private func stopPlayer() {
    player?.stop()
    player = nil
    playerPath = nil
    try? session.setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func suspend() {
    pause()
    player?.pause()
  }
}
