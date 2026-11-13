package __PACKAGE__;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.provider.OpenableColumns;
import android.view.WindowManager;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Recursos de plataforma usados pela pedaleira (canal "pedaleira/platform"):
 * permissão de microfone, seletor de arquivos para IRs, lista de dispositivos de
 * áudio e tela sempre ligada. O áudio em si roda no motor nativo (C++/AAudio).
 *
 * Escrita em Java para não depender do plugin Kotlin do Gradle: o Android
 * sempre compila código Java, então a tela inicial nunca fica de fora do app.
 */
public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "pedaleira/platform";
    private static final int REQ_MIC = 4101;
    private static final int REQ_PICK = 4102;

    private MethodChannel.Result pendingPermission;
    private MethodChannel.Result pendingPick;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "requestMicPermission":
                            requestMic(result);
                            break;
                        case "filesDir":
                            result.success(getFilesDir().getAbsolutePath());
                            break;
                        case "pickWav":
                            pickWav(result);
                            break;
                        case "listDevices":
                            result.success(listDevices());
                            break;
                        case "keepScreenOn":
                            if (Boolean.TRUE.equals(call.arguments)) {
                                getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            } else {
                                getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                            }
                            result.success(null);
                            break;
                        case "deviceInfo": {
                            Map<String, Object> info = new HashMap<>();
                            info.put("sdk", Build.VERSION.SDK_INT);
                            info.put("package", getPackageName());
                            info.put("model", Build.MANUFACTURER + " " + Build.MODEL);
                            info.put("lowLatency", getPackageManager().hasSystemFeature(PackageManager.FEATURE_AUDIO_LOW_LATENCY));
                            info.put("proAudio", getPackageManager().hasSystemFeature(PackageManager.FEATURE_AUDIO_PRO));
                            result.success(info);
                            break;
                        }
                        case "openUrl":
                            try {
                                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse((String) call.arguments)));
                                result.success(true);
                            } catch (Exception e) {
                                result.success(false);
                            }
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    // ------------------------------------------------------------ microfone
    private void requestMic(MethodChannel.Result result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            result.success(true);
            return;
        }
        if (pendingPermission != null) pendingPermission.success(false);
        pendingPermission = result;
        requestPermissions(new String[] {Manifest.permission.RECORD_AUDIO}, REQ_MIC);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_MIC && pendingPermission != null) {
            pendingPermission.success(grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED);
            pendingPermission = null;
        }
    }

    // ------------------------------------------------------------ arquivos de IR
    private void pickWav(MethodChannel.Result result) {
        if (pendingPick != null) pendingPick.success(null);
        pendingPick = result;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_MIME_TYPES,
                new String[] {"audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave", "application/octet-stream"});
        try {
            startActivityForResult(intent, REQ_PICK);
        } catch (Exception e) {
            pendingPick = null;
            result.error("no_picker", e.getMessage(), null);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_PICK) return;
        final MethodChannel.Result result = pendingPick;
        if (result == null) return;
        pendingPick = null;
        final Uri uri = data == null ? null : data.getData();
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null);
            return;
        }
        new Thread(() -> {
            try {
                String picked = displayName(uri);
                final String name = picked == null ? "ir.wav" : picked;
                File dir = new File(getFilesDir(), "irs");
                dir.mkdirs();
                File dest = uniqueFile(dir, name.replaceAll("[^A-Za-z0-9._ -]", "_"));
                try (InputStream in = getContentResolver().openInputStream(uri)) {
                    if (in == null) throw new IllegalStateException("não foi possível ler o arquivo");
                    try (OutputStream out = new FileOutputStream(dest)) {
                        byte[] buf = new byte[65536];
                        int n;
                        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    }
                }
                final Map<String, Object> r = new HashMap<>();
                r.put("path", dest.getAbsolutePath());
                r.put("name", name);
                runOnUiThread(() -> result.success(r));
            } catch (Exception e) {
                runOnUiThread(() -> result.error("copy_failed", e.getMessage(), null));
            }
        }).start();
    }

    private String displayName(Uri uri) {
        try (Cursor c = getContentResolver().query(uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (c != null && c.moveToFirst()) return c.getString(0);
        } catch (Exception ignored) {
            // sem nome: usa o padrão
        }
        return null;
    }

    private static File uniqueFile(File dir, String name) {
        int dot = name.lastIndexOf('.');
        String base = dot < 0 ? name : name.substring(0, dot);
        String ext = dot < 0 ? "wav" : name.substring(dot + 1);
        File f = new File(dir, name);
        int i = 1;
        while (f.exists()) {
            f = new File(dir, base + "_" + i + "." + ext);
            i++;
        }
        return f;
    }

    // ------------------------------------------------------------ dispositivos
    private List<Map<String, Object>> listDevices() {
        AudioManager am = (AudioManager) getSystemService(AUDIO_SERVICE);
        List<Map<String, Object>> out = new ArrayList<>();
        for (AudioDeviceInfo d : am.getDevices(AudioManager.GET_DEVICES_ALL)) {
            int t = d.getType();
            if (t == AudioDeviceInfo.TYPE_TELEPHONY
                    || t == AudioDeviceInfo.TYPE_FM_TUNER
                    || t == AudioDeviceInfo.TYPE_TV_TUNER
                    || t == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                    || t == 25 /* TYPE_REMOTE_SUBMIX */) {
                continue;
            }
            Map<String, Object> m = new HashMap<>();
            m.put("id", d.getId());
            m.put("name", typeName(t) + " · " + d.getProductName());
            m.put("input", d.isSource());
            m.put("output", d.isSink());
            m.put("type", t);
            out.add(m);
        }
        return out;
    }

    private static String typeName(int t) {
        switch (t) {
            case AudioDeviceInfo.TYPE_BUILTIN_MIC: return "Microfone interno";
            case AudioDeviceInfo.TYPE_BUILTIN_SPEAKER: return "Alto-falante";
            case AudioDeviceInfo.TYPE_WIRED_HEADSET: return "Fone com microfone (P2)";
            case AudioDeviceInfo.TYPE_WIRED_HEADPHONES: return "Fone com fio";
            case AudioDeviceInfo.TYPE_USB_DEVICE: return "Interface USB";
            case AudioDeviceInfo.TYPE_USB_HEADSET: return "Headset USB";
            case AudioDeviceInfo.TYPE_USB_ACCESSORY: return "Acessório USB";
            case AudioDeviceInfo.TYPE_LINE_ANALOG: return "Linha analógica";
            case AudioDeviceInfo.TYPE_LINE_DIGITAL: return "Linha digital";
            case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP: return "Bluetooth";
            case AudioDeviceInfo.TYPE_BLUETOOTH_SCO: return "Bluetooth (chamada)";
            case 26:
            case 27:
            case 30:
                return "Bluetooth LE";
            default:
                return "Dispositivo " + t;
        }
    }
}
