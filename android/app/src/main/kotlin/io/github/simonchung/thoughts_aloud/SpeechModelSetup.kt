package io.github.simonchung.thoughts_aloud

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/** Resolves the service's BCP 47 tag before opening the microphone. Main thread only. */
internal class SpeechModelSetup(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var checker: SpeechRecognizer? = null
    private var prepared: SpeechRecognizer? = null

    fun takePrepared(): SpeechRecognizer? = prepared.also { prepared = null }
    private var reply: ((String?) -> Unit)? = null

    fun prepare(requested: String, done: (String?) -> Unit) {
        cancel()
        if (Build.VERSION.SDK_INT < 33 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
            done(null)
            return
        }
        reply = done
        try {
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            checker = recognizer
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, requested)
            handler.postDelayed({ complete(null) }, 45_000)
            check(recognizer, intent, requested, allowDownload = true)
        } catch (_: RuntimeException) {
            complete(null)
        }
    }

    @android.annotation.TargetApi(33)
    private fun check(sr: SpeechRecognizer, intent: Intent, requested: String, allowDownload: Boolean) {
        sr.checkRecognitionSupport(intent, context.mainExecutor, object : RecognitionSupportCallback {
            override fun onSupportResult(support: RecognitionSupport) {
                if (checker !== sr) return
                val installed = matchLanguage(requested, support.installedOnDeviceLanguages)
                if (installed != null) { complete(installed); return }
                val pending = matchLanguage(requested, support.pendingOnDeviceLanguages)
                val offered = matchLanguage(requested, support.supportedOnDeviceLanguages)
                val tag = pending ?: offered
                if (tag == null) { complete(null); return }
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, tag)
                if (pending != null || !allowDownload) {
                    pollInstalled(sr, intent, requested)
                    return
                }
                try {
                    if (Build.VERSION.SDK_INT >= 34) {
                        sr.triggerModelDownload(intent, context.mainExecutor, object : ModelDownloadListener {
                            override fun onSuccess() { if (checker === sr) complete(tag) }
                            override fun onProgress(percent: Int) {}
                            override fun onScheduled() { if (checker === sr) pollInstalled(sr, intent, requested) }
                            override fun onError(error: Int) {
                                if (checker !== sr) return
                                if (error == SpeechRecognizer.ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS) {
                                    pollInstalled(sr, intent, requested)
                                } else {
                                    complete(null)
                                }
                            }
                        })
                    } else {
                        sr.triggerModelDownload(intent)
                        pollInstalled(sr, intent, requested)
                    }
                } catch (_: RuntimeException) { complete(null) }
            }

            override fun onError(error: Int) {
                // Some services accept recognition but do not implement capability discovery.
                if (checker === sr) complete(requested)
            }
        })
    }

    @android.annotation.TargetApi(33)
    private fun pollInstalled(sr: SpeechRecognizer, intent: Intent, requested: String) {
        handler.postDelayed({
            if (checker === sr) {
                try { check(sr, intent, requested, allowDownload = false) }
                catch (_: RuntimeException) { complete(null) }
            }
        }, 1000)
    }

    fun cancel() {
        takePrepared()?.destroy()
        complete(null)
    }

    private fun complete(tag: String?) {
        val callback = reply
        reply = null
        val sr = checker
        checker = null
        handler.removeCallbacksAndMessages(null)
        if (tag != null) {
            // Reuse the bound service. An immediate destroy/rebind can disconnect
            // the recognition session before the provider consumes its first audio.
            prepared = sr
        } else {
            sr?.destroy()
        }
        callback?.invoke(tag)
    }

    companion object {
        fun matchLanguage(requested: String, available: List<String>): String? {
            val candidates = when (requested) {
                "zh-TW" -> listOf("zh-TW", "zh-Hant-TW", "cmn-Hant-TW", "cmn-TW", "zh-Hant", "cmn-Hant")
                else -> listOf(requested)
            }
            return candidates.firstNotNullOfOrNull { tag -> available.firstOrNull { it.equals(tag, ignoreCase = true) } }
        }
    }
}
