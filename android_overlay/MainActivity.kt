package __PACKAGE__

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Recursos de plataforma usados pela pedaleira (canal "pedaleira/platform"):
 * permissão de microfone, seletor de arquivos para IRs, lista de dispositivos de
 * áudio e tela sempre ligada. O áudio em si roda no motor nativo (C++/AAudio).
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestMicPermission" -> requestMic(result)
                "filesDir" -> result.success(filesDir.absolutePath)
                "pickWav" -> pickWav(result)
                "listDevices" -> result.success(listDevices())
                "keepScreenOn" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "deviceInfo" -> result.success(
                    mapOf(
                        "sdk" to Build.VERSION.SDK_INT,
                        "package" to packageName,
                        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "lowLatency" to packageManager.hasSystemFeature(PackageManager.FEATURE_AUDIO_LOW_LATENCY),
                        "proAudio" to packageManager.hasSystemFeature(PackageManager.FEATURE_AUDIO_PRO),
                    )
                )
                "openUrl" -> {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ------------------------------------------------------------ microfone
    private fun requestMic(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQ_MIC)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_MIC) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }

    // ------------------------------------------------------------ arquivos de IR
    private fun pickWav(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave", "application/octet-stream"),
            )
        }
        try {
            startActivityForResult(intent, REQ_PICK)
        } catch (e: Exception) {
            pendingPick = null
            result.error("no_picker", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                val name = displayName(uri) ?: "ir.wav"
                val dir = File(filesDir, "irs").apply { mkdirs() }
                val dest = uniqueFile(dir, name.replace(Regex("[^A-Za-z0-9._ -]"), "_"))
                val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("não foi possível ler o arquivo")
                input.use { src -> dest.outputStream().use { src.copyTo(it) } }
                runOnUiThread { result.success(mapOf("path" to dest.absolutePath, "name" to name)) }
            } catch (e: Exception) {
                runOnUiThread { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }

    private fun uniqueFile(dir: File, name: String): File {
        val base = name.substringBeforeLast('.')
        val ext = name.substringAfterLast('.', "wav")
        var f = File(dir, name)
        var i = 1
        while (f.exists()) {
            f = File(dir, "${base}_$i.$ext")
            i++
        }
        return f
    }

    // ------------------------------------------------------------ dispositivos
    private fun listDevices(): List<Map<String, Any>> {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val ignored = setOf(
            AudioDeviceInfo.TYPE_TELEPHONY,
            AudioDeviceInfo.TYPE_FM_TUNER,
            AudioDeviceInfo.TYPE_TV_TUNER,
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE,
            25, // TYPE_REMOTE_SUBMIX
        )
        return am.getDevices(AudioManager.GET_DEVICES_ALL)
            .filter { it.type !in ignored }
            .map { d ->
                mapOf(
                    "id" to d.id,
                    "name" to "${typeName(d.type)} · ${d.productName}",
                    "input" to d.isSource,
                    "output" to d.isSink,
                    "type" to d.type,
                )
            }
    }

    private fun typeName(t: Int): String = when (t) {
        AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Microfone interno"
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Alto-falante"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Fone com microfone (P2)"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Fone com fio"
        AudioDeviceInfo.TYPE_USB_DEVICE -> "Interface USB"
        AudioDeviceInfo.TYPE_USB_HEADSET -> "Headset USB"
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "Acessório USB"
        AudioDeviceInfo.TYPE_LINE_ANALOG -> "Linha analógica"
        AudioDeviceInfo.TYPE_LINE_DIGITAL -> "Linha digital"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth (chamada)"
        26, 27, 30 -> "Bluetooth LE"
        else -> "Dispositivo $t"
    }

    companion object {
        private const val CHANNEL = "pedaleira/platform"
        private const val REQ_MIC = 4101
        private const val REQ_PICK = 4102
    }
}
