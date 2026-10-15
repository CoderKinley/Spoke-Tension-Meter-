package org.spokelab.spoke_lab

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.*
import android.media.audiofx.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    @Volatile private var recording = false
    @Volatile private var generation = 0
    private var permissionResult: MethodChannel.Result? = null
    private var exportResult: MethodChannel.Result? = null
    private var exportContent: String? = null
    private val effects = mutableListOf<AudioEffect>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "org.spokelab/pcm").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
            override fun onCancel(arguments: Any?) { stopCapture(); sink = null }
        })
        MethodChannel(messenger, "org.spokelab/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (permissionResult != null || recording) {
                        result.error("busy", "Microphone is already starting or recording.", null)
                    } else if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        permissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 401)
                    } else { startCapture(result) }
                }
                "stop" -> {
                    permissionResult?.error("cancelled", "Microphone start cancelled.", null)
                    permissionResult = null
                    stopCapture(); result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "org.spokelab/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "directory" -> result.success(filesDir.absolutePath)
                "export" -> {
                    if (exportResult != null) { result.error("busy", "An export is already open.", null) }
                    else {
                        exportContent = call.argument<String>("content") ?: ""
                        exportResult = result
                        try {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mime") ?: "application/json"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "spoke-lab.json")
                            }
                            startActivityForResult(intent, 402)
                        } catch (e: Exception) {
                            exportResult = null; exportContent = null
                            result.error("export", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, permissions, grants)
        if (code != 401) return
        val result = permissionResult ?: return
        permissionResult = null
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED) { startCapture(result) }
        else { result.error("permission", "Microphone access is needed. Allow it in Android app settings to measure.", null) }
    }

    private fun startCapture(result: MethodChannel.Result) {
        try {
            if (sink == null) { result.error("stream", "Audio stream is not ready. Try again.", null); return }
            val manager = getSystemService(AUDIO_SERVICE) as AudioManager
            val rawSupported = Build.VERSION.SDK_INT >= 24 &&
                manager.getProperty(AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED) == "true"
            val source = if (rawSupported) MediaRecorder.AudioSource.UNPROCESSED else MediaRecorder.AudioSource.VOICE_RECOGNITION
            var chosen: AudioRecord? = null
            for (rate in intArrayOf(48000, 44100)) {
                val minimum = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minimum <= 0) continue
                val candidate = AudioRecord.Builder().setAudioSource(source).setAudioFormat(
                    AudioFormat.Builder().setSampleRate(rate).setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO).build())
                    .setBufferSizeInBytes(maxOf(minimum * 2, 32768)).build()
                if (candidate.state == AudioRecord.STATE_INITIALIZED) { chosen = candidate; break }
                candidate.release()
            }
            val audio = chosen ?: throw IllegalStateException("No supported mono PCM microphone format.")
            recorder = audio
            val builtin = manager.getDevices(AudioManager.GET_DEVICES_INPUTS).firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
            if (builtin != null) audio.setPreferredDevice(builtin)
            disableEffects(audio.audioSessionId)
            audio.startRecording()
            if (audio.recordingState != AudioRecord.RECORDSTATE_RECORDING) throw IllegalStateException("Microphone could not start.")
            val initialRoute = audio.routedDevice
            if (initialRoute != null && initialRoute.type != AudioDeviceInfo.TYPE_BUILTIN_MIC) {
                throw IllegalStateException("Disconnect the external microphone or headset and try again.")
            }
            recording = true
            val token = ++generation
            if (Build.VERSION.SDK_INT >= 24) {
                audio.addOnRoutingChangedListener({ routing ->
                    val routed = routing.routedDevice
                    if (recording && token == generation && routed != null && routed.type != AudioDeviceInfo.TYPE_BUILTIN_MIC) {
                        stopCapture()
                        sink?.error("route", "Microphone route changed. Disconnect the headset and start again.", null)
                    }
                }, handler)
            }
            result.success(mapOf("sampleRate" to audio.sampleRate,
                "source" to if (rawSupported) "unprocessed" else "voice recognition",
                "device" to "${Build.MANUFACTURER} ${Build.MODEL} / Android ${Build.VERSION.RELEASE}"))
            worker = thread(name = "SpokeLabPCM") {
                val buffer = ByteArray(4096)
                var sequence = 0
                try {
                    while (recording && token == generation) {
                        val read = audio.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                        if (read <= 0) {
                            if (recording && token == generation) throw IllegalStateException("Audio input stopped ($read).")
                            break
                        }
                        val packet = mapOf("pcm" to buffer.copyOf(read), "sampleRate" to audio.sampleRate, "sequence" to sequence++)
                        handler.post { if (recording && token == generation) sink?.success(packet) }
                    }
                } catch (e: Exception) {
                    handler.post {
                        if (recording && token == generation) {
                            stopCapture(); sink?.error("capture", e.message ?: "Audio capture interrupted.", null)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            stopCapture(); result.error("capture", e.message ?: "Microphone unavailable.", null)
        }
    }

    private fun disableEffects(session: Int) {
        if (AutomaticGainControl.isAvailable()) AutomaticGainControl.create(session)?.let { it.enabled = false; effects.add(it) }
        if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(session)?.let { it.enabled = false; effects.add(it) }
        if (AcousticEchoCanceler.isAvailable()) AcousticEchoCanceler.create(session)?.let { it.enabled = false; effects.add(it) }
    }

    private fun stopCapture() {
        recording = false; generation++
        try { recorder?.stop() } catch (_: IllegalStateException) { }
        worker?.join(500); worker = null
        effects.forEach { it.release() }; effects.clear()
        recorder?.release(); recorder = null
    }

    override fun onPause() {
        if (recording) {
            stopCapture(); sink?.error("paused", "Recording paused while the app is in the background.", null)
        }
        super.onPause()
    }

    override fun onDestroy() {
        stopCapture()
        permissionResult?.error("closed", "Activity closed.", null); permissionResult = null
        exportResult?.error("closed", "Export interrupted.", null); exportResult = null; exportContent = null
        super.onDestroy()
    }

    @Deprecated("Android compatibility callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 402) return
        val result = exportResult ?: return
        val content = exportContent ?: ""
        exportResult = null; exportContent = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(false); return }
        thread(name = "SpokeLabExport") {
            try {
                val output = contentResolver.openOutputStream(uri) ?: throw IllegalStateException("Cannot open export destination.")
                output.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                handler.post { result.success(true) }
            } catch (e: Exception) { handler.post { result.error("export", e.message, null) } }
        }
    }
}
