package io.github.simonchung.thoughts_aloud

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var permission: MethodChannel.Result? = null
    private val speechModels by lazy { SpeechModelSetup(this) }
    private var capture: VoiceCapture? = null
    private var player: MediaPlayer? = null
    private var completed = false
    private var playbackPath: String? = null
    private val drafts get() = File(cacheDir, "voice-drafts")
    private val library get() = File(filesDir, "voice-cards")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "io.github.simonchung.thoughts_aloud/voice").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            try {
                when (call.method) {
                    "library" -> { library.mkdirs(); result.success(library.absolutePath) }
                    "access" -> {
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else if (permission == null) {
                            permission = result
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1042)
                        } else result.error("busy", "Permission request pending", null)
                    }
                    "prepareSpeech" -> speechModels.prepare(call.argument<String>("locale")!!) { result.success(it) }
                    "skipSpeechSetup" -> { speechModels.cancel(); result.success(null) }
                    "draft" -> {
                        val id = UUID.randomUUID().toString()
                        val dir = File(drafts, id)
                        check(dir.mkdirs())
                        result.success(mapOf("id" to id, "path" to File(dir, "voice.wav").absolutePath))
                    }
                    "start" -> {
                        val file = File(path!!)
                        require(file.parentFile?.parentFile == drafts && file.name == "voice.wav")
                        val session = capture ?: VoiceCapture(this, file).also { capture = it }
                        require(session.file == file)
                        session.start(call.argument<String>("locale"), speechModels::takePrepared)
                        result.success(session.status())
                    }
                    "status", "pause", "finish" -> {
                        val session = checkNotNull(capture)
                        require(path == session.file.absolutePath)
                        if (call.method != "status" || session.failed) session.pause()
                        if (call.method == "status") {
                            result.success(session.status())
                        } else {
                            session.afterSpeechEnd {
                                val state = session.status()
                                if (call.method == "finish") {
                                    session.close()
                                    if (capture === session) capture = null
                                }
                                result.success(state)
                            }
                        }
                    }
                    "discard" -> {
                        val file = File(path!!)
                        require(file.parentFile?.parentFile == drafts && file.name == "voice.wav")
                        if (capture?.file == file) { capture?.close(); capture = null }
                        file.parentFile?.deleteRecursively()
                        result.success(null)
                    }
                    "play" -> {
                        stopPlayer()
                        val p = MediaPlayer()
                        player = p
                        playbackPath = path
                        p.setDataSource(path!!)
                        p.prepare()
                        p.seekTo(call.argument<Int>("position")!!.coerceIn(0, p.duration))
                        completed = false
                        p.setOnCompletionListener { if (player === it) completed = true }
                        p.start()
                        result.success(null)
                    }
                    "player" -> {
                        val p = player
                        require(p != null && path == playbackPath)
                        result.success(mapOf("position" to p.currentPosition, "playing" to p.isPlaying, "completed" to completed))
                    }
                    "stopPlayer" -> {
                        if (path == playbackPath) stopPlayer()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                if (call.method == "play") stopPlayer()
                result.error("media", e.localizedMessage, null)
            }
        }
    }

    private fun stopPlayer() {
        player?.release()
        player = null
        playbackPath = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1042) {
            permission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permission = null
        }
    }

    override fun onStop() {
        capture?.pause()
        player?.let { if (it.isPlaying) it.pause() }
        super.onStop()
    }

    override fun onDestroy() {
        speechModels.cancel()
        capture?.close()
        stopPlayer()
        super.onDestroy()
    }
}
