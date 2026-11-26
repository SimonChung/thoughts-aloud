package io.github.simonchung.thoughts_aloud

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.speech.SpeechRecognizer
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max

/** The WAV sample count is also the recording clock. Pauses add no samples. */
internal class VoiceCapture(private val context: Context, val file: File) {
    private val rate = 16000
    private val speech = LiveSpeech(context)
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    @Volatile private var running = false
    @Volatile var failed = false
        private set
    @Volatile private var bytes = 0L
    @Volatile private var level = 0.0

    @SuppressLint("MissingPermission")
    fun start(locale: String?, prepared: () -> SpeechRecognizer?) {
        if (running) return
        pause()
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        check(min > 0)
        val mic = AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT, max(min * 2, 8192))
        recorder = mic
        try {
            check(mic.state == AudioRecord.STATE_INITIALIZED)
            mic.startRecording()
            check(mic.recordingState == AudioRecord.RECORDSTATE_RECORDING)
            speech.start(locale, rate, prepared())
            failed = false
            running = true
            worker = Thread({
                try {
                    RandomAccessFile(file, "rw").use { out ->
                        out.seek(44 + bytes)
                        val data = ByteArray(2048)
                        try {
                            while (running) {
                                val n = mic.read(data, 0, data.size)
                                if (n <= 0) { if (running) error("Audio read failed"); break }
                                check(bytes + n < 0xffffffffL - 36)
                                out.write(data, 0, n)
                                bytes += n
                                var peak = 0
                                for (i in 0 until n - 1 step 2) {
                                    val sample = (data[i].toInt() and 255) or (data[i + 1].toInt() shl 8)
                                    peak = max(peak, abs(sample))
                                }
                                level = peak / 32768.0
                                speech.feed(data, n)
                            }
                        } finally {
                            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                            header.put("RIFF".toByteArray()).putInt((36 + bytes).toInt()).put("WAVEfmt ".toByteArray())
                                .putInt(16).putShort(1).putShort(1).putInt(rate).putInt(rate * 2)
                                .putShort(2).putShort(16).put("data".toByteArray()).putInt(bytes.toInt())
                            out.seek(0)
                            out.write(header.array())
                        }
                    }
                } catch (_: Exception) { failed = true }
                finally { running = false }
            }, "voice-capture").also { it.start() }
        } catch (e: Exception) { pause(); throw e }
    }

    fun pause() {
        running = false
        val mic = recorder
        if (mic?.recordingState == AudioRecord.RECORDSTATE_RECORDING) mic.stop()
        worker?.join()
        worker = null
        mic?.release()
        recorder = null
        level = 0.0
        speech.endInput()
    }

    fun status() = mapOf("milliseconds" to bytes * 1000 / (2 * rate),
        "running" to running, "failed" to failed, "level" to level, "text" to speech.text,
        "transcribing" to speech.available)

    fun afterSpeechEnd(done: () -> Unit) = speech.afterEnd(done)

    fun close() { pause(); speech.close() }
}
