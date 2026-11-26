package io.github.simonchung.thoughts_aloud

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.system.Os
import android.system.OsConstants
import android.util.Log

/** Feed the same PCM as the saved audio. A stalled recognizer must never block the recorder. */
internal class LiveSpeech(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var drained: Runnable? = null
    private var recognizer: SpeechRecognizer? = null
    private var readEnd: ParcelFileDescriptor? = null
    @Volatile private var writeEnd: ParcelFileDescriptor? = null
    @Volatile var available = false
        private set
    private val segments = mutableListOf<String>()
    private var partial = ""
    private var generation = 0
    val text get() = (segments + partial).filter { it.isNotBlank() }.joinToString(" ")

    fun start(locale: String?, rate: Int, prepared: SpeechRecognizer? = null) {
        if (available || (prepared != null && recognizer !== prepared)) close() else endSession()
        if (locale == null || Build.VERSION.SDK_INT < 33 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) return
        try {
            val sr = prepared ?: recognizer ?: SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            recognizer = sr
            val token = generation
            sr.setRecognitionListener(object : RecognitionListener {
                private fun words(bundle: Bundle?) =
                    bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()

                override fun onPartialResults(bundle: Bundle?) {
                    if (token == generation) partial = words(bundle).ifBlank { partial }
                }
                override fun onSegmentResults(bundle: Bundle) {
                    if (token == generation) commit(words(bundle))
                }
                override fun onResults(bundle: Bundle?) {
                    if (token == generation) {
                        val finalWords = words(bundle)
                        val continueListening = writeEnd != null && finalWords.isNotBlank()
                        commit(finalWords)
                        endSession()
                        if (continueListening) start(locale, rate)
                    }
                }
                override fun onEndOfSegmentedSession() { if (token == generation) endSession() }
                override fun onError(error: Int) {
                    if (token == generation) {
                        Log.w("ThoughtsAloudSpeech", "Recognition stopped (Android error $error)")
                        close()
                    }
                }
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            val ends = ParcelFileDescriptor.createPipe()
            readEnd = ends[0]
            writeEnd = ends[1]
            Os.fcntlInt(ends[1].fileDescriptor, OsConstants.F_SETFL, OsConstants.O_NONBLOCK)
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, ends[0])
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, rate)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                .putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
            sr.startListening(intent)
            available = true
        } catch (error: Exception) {
            Log.w("ThoughtsAloudSpeech", "Unable to start local recognition", error)
            close()
        }
    }

    @Synchronized fun feed(data: ByteArray, size: Int) {
        val writer = writeEnd ?: return
        try {
            Os.write(writer.fileDescriptor, data, 0, size)
        } catch (e: android.system.ErrnoException) {
            // The model can take time to start. Continue recording independently.
            if (e.errno != OsConstants.EAGAIN) {
                Log.w("ThoughtsAloudSpeech", "Audio pipe closed (errno ${e.errno})")
                endInput()
                available = false
            }
        } catch (e: Exception) {
            Log.w("ThoughtsAloudSpeech", "Audio pipe failed", e)
            endInput()
            available = false
        }
    }

    @Synchronized fun endInput() { writeEnd?.close(); writeEnd = null }
    // EOF can precede the service's final result. Let the editor save the last
    // words even when the user taps Save immediately after stopping.
    fun afterEnd(done: () -> Unit) {
        if (!available) { done(); return }
        val callback = Runnable {
            drained = null
            done()
        }
        drained = callback
        handler.postDelayed(callback, 2_500)
    }

    private fun commit(final: String) {
        val words = final.ifBlank { partial }
        if (words.isNotBlank()) segments.add(words)
        partial = ""
    }
    private fun endSession() {
        generation++
        commit("")
        endInput()
        readEnd?.close()
        readEnd = null
        available = false
        drained?.let { handler.removeCallbacks(it); it.run() }
    }
    fun close() {
        val sr = recognizer
        recognizer = null
        endSession()
        sr?.destroy()
    }

}
