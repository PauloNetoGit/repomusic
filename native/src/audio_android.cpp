// Full-duplex com AAudio (Android 9+ / API 28).
// O fluxo de saída roda em callback de baixa latência; dentro dele lemos o fluxo
// de entrada sem bloquear (mesma técnica do FullDuplexStream do Oboe).
#include <aaudio/AAudio.h>
#include <android/log.h>

#include <atomic>
#include <cstring>
#include <mutex>
#include <thread>
#include <vector>

#include "audio.h"
#include "engine.h"

#define LOG_TAG "PedalEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace rig {
namespace {

struct Duplex {
    AAudioStream* in = nullptr;
    AAudioStream* out = nullptr;
    std::vector<float> inBuf;
    int inCh = 1, outCh = 2;
    int inDev = 0, outDev = 0;
    int burst = 192, maxBuffer = 0;
    int lastXruns = 0;
    std::atomic<bool> drain{true};
    std::atomic<bool> restarting{false};
    std::recursive_mutex mu;
};

Duplex g;

// Denormais em filtros IIR derrubam a performance em ARM: liga flush-to-zero.
inline void enableFlushToZero() {
    static thread_local bool done = false;
    if (done) return;
    done = true;
#if defined(__aarch64__)
    uint64_t fpcr;
    asm volatile("mrs %0, fpcr" : "=r"(fpcr));
    asm volatile("msr fpcr, %0" ::"r"(fpcr | (1ull << 24)));
#elif defined(__x86_64__) || defined(__i386__)
    __builtin_ia32_ldmxcsr(__builtin_ia32_stmxcsr() | 0x8040);
#endif
}

aaudio_data_callback_result_t dataCallback(AAudioStream*, void*, void* audioData, int32_t frames) {
    enableFlushToZero();
    float* out = static_cast<float*>(audioData);
    const size_t need = static_cast<size_t>(frames) * g.inCh;
    if (need > g.inBuf.size()) {
        std::memset(out, 0, sizeof(float) * frames * g.outCh);
        return AAUDIO_CALLBACK_RESULT_CONTINUE;
    }
    int32_t got = 0;
    if (g.in) {
        if (g.drain.exchange(false)) {
            // Descarta o que acumulou na entrada antes do primeiro ciclo: menor latência.
            int32_t r;
            int guard = 0;
            do { r = AAudioStream_read(g.in, g.inBuf.data(), frames, 0); } while (r == frames && ++guard < 64);
        }
        got = AAudioStream_read(g.in, g.inBuf.data(), frames, 0);
        if (got < 0) got = 0;
    }
    if (got < frames) std::memset(g.inBuf.data() + static_cast<size_t>(got) * g.inCh, 0, sizeof(float) * (frames - got) * g.inCh);
    if (g.inCh > 1)
        for (int i = 0; i < frames; ++i) g.inBuf[i] = g.inBuf[static_cast<size_t>(i) * g.inCh];
    Engine::instance().processAudio(g.inBuf.data(), out, frames, g.outCh);
    return AAUDIO_CALLBACK_RESULT_CONTINUE;
}

void restartAfterDisconnect();

void errorCallback(AAudioStream*, void*, aaudio_result_t error) {
    LOGE("erro no fluxo: %s", AAudio_convertResultToText(error));
    if (error == AAUDIO_ERROR_DISCONNECTED) {
        // Não é permitido fechar/reabrir dentro do callback: faz em outra thread.
        if (!g.restarting.exchange(true)) std::thread(restartAfterDisconnect).detach();
    }
}

AAudioStream* openStream(aaudio_direction_t dir, int device, int sampleRate, int channels, bool exclusive,
                         aaudio_input_preset_t preset, aaudio_result_t& res) {
    AAudioStreamBuilder* b = nullptr;
    res = AAudio_createStreamBuilder(&b);
    if (res != AAUDIO_OK) return nullptr;
    AAudioStreamBuilder_setDirection(b, dir);
    if (device > 0) AAudioStreamBuilder_setDeviceId(b, device);
    AAudioStreamBuilder_setSharingMode(b, exclusive ? AAUDIO_SHARING_MODE_EXCLUSIVE : AAUDIO_SHARING_MODE_SHARED);
    AAudioStreamBuilder_setPerformanceMode(b, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    AAudioStreamBuilder_setFormat(b, AAUDIO_FORMAT_PCM_FLOAT);
    AAudioStreamBuilder_setChannelCount(b, channels);
    if (sampleRate > 0) AAudioStreamBuilder_setSampleRate(b, sampleRate);
    if (dir == AAUDIO_DIRECTION_INPUT) {
        AAudioStreamBuilder_setInputPreset(b, preset);
    } else {
        AAudioStreamBuilder_setUsage(b, AAUDIO_USAGE_MEDIA);
        AAudioStreamBuilder_setContentType(b, AAUDIO_CONTENT_TYPE_MUSIC);
        AAudioStreamBuilder_setDataCallback(b, dataCallback, nullptr);
    }
    AAudioStreamBuilder_setErrorCallback(b, errorCallback, nullptr);
    AAudioStream* s = nullptr;
    res = AAudioStreamBuilder_openStream(b, &s);
    AAudioStreamBuilder_delete(b);
    return res == AAUDIO_OK ? s : nullptr;
}

void closeStream(AAudioStream*& s) {
    if (!s) return;
    AAudioStream_requestStop(s);
    aaudio_stream_state_t next = AAUDIO_STREAM_STATE_UNINITIALIZED;
    AAudioStream_waitForStateChange(s, AAUDIO_STREAM_STATE_STOPPING, &next, 200 * 1000000LL);
    AAudioStream_close(s);
    s = nullptr;
}

void stopLocked() {
    closeStream(g.out);  // primeiro a saída: o callback para de rodar
    closeStream(g.in);
    Engine::instance().setRunning(false);
}

int startLocked(int inDev, int outDev, std::string& err) {
    stopLocked();
    g.inDev = inDev;
    g.outDev = outDev;
    aaudio_result_t res;

    g.out = openStream(AAUDIO_DIRECTION_OUTPUT, outDev, 0, 2, true, 0, res);
    if (!g.out) g.out = openStream(AAUDIO_DIRECTION_OUTPUT, outDev, 0, 2, false, 0, res);
    if (!g.out) { err = std::string("Falha ao abrir a saída de áudio: ") + AAudio_convertResultToText(res); return -1; }
    const int sr = AAudioStream_getSampleRate(g.out);
    g.outCh = AAudioStream_getChannelCount(g.out);

    const aaudio_input_preset_t presets[2] = {AAUDIO_INPUT_PRESET_UNPROCESSED, AAUDIO_INPUT_PRESET_VOICE_RECOGNITION};
    for (int attempt = 0; attempt < 4 && !g.in; ++attempt) {
        const bool excl = attempt < 2;
        g.in = openStream(AAUDIO_DIRECTION_INPUT, inDev, sr, 1, excl, presets[attempt & 1], res);
        if (g.in && AAudioStream_getSampleRate(g.in) != sr) closeStream(g.in);
    }
    if (!g.in) {
        closeStream(g.out);
        err = std::string("Falha ao abrir a entrada de áudio (permissão de microfone?): ") + AAudio_convertResultToText(res);
        return -2;
    }
    g.inCh = AAudioStream_getChannelCount(g.in);

    g.burst = std::max(16, AAudioStream_getFramesPerBurst(g.out));
    AAudioStream_setBufferSizeInFrames(g.out, g.burst * 2);
    g.maxBuffer = std::min(AAudioStream_getBufferCapacityInFrames(g.out), g.burst * 8);
    g.lastXruns = 0;
    const int cap = std::max(8192, AAudioStream_getBufferCapacityInFrames(g.out) * 2);
    g.inBuf.assign(static_cast<size_t>(cap) * std::max(1, g.inCh), 0.f);

    Engine& e = Engine::instance();
    e.configure(static_cast<float>(sr), cap);
    e.setRunning(true);
    g.drain.store(true);

    res = AAudioStream_requestStart(g.in);
    if (res == AAUDIO_OK) res = AAudioStream_requestStart(g.out);
    if (res != AAUDIO_OK) {
        stopLocked();
        err = std::string("Falha ao iniciar o áudio: ") + AAudio_convertResultToText(res);
        return -3;
    }
    LOGI("áudio iniciado: %d Hz, burst %d, in %s, out %s", sr, g.burst,
         AAudioStream_getSharingMode(g.in) == AAUDIO_SHARING_MODE_EXCLUSIVE ? "exclusivo" : "compartilhado",
         AAudioStream_getSharingMode(g.out) == AAUDIO_SHARING_MODE_EXCLUSIVE ? "exclusivo" : "compartilhado");
    return 0;
}

void restartAfterDisconnect() {
    {
        std::lock_guard<std::recursive_mutex> lock(g.mu);
        if (g.out || g.in) {
            std::string err;
            // Dispositivo mudou (ex.: fone/USB desconectado): volta para o padrão.
            if (startLocked(0, 0, err) != 0) {
                LOGE("falha ao reiniciar: %s", err.c_str());
                stopLocked();
            }
        }
    }
    g.restarting.store(false);
}

}  // namespace

int audioStart(int inputDeviceId, int outputDeviceId, std::string& err) {
    std::lock_guard<std::recursive_mutex> lock(g.mu);
    return startLocked(inputDeviceId, outputDeviceId, err);
}

void audioStop() {
    std::lock_guard<std::recursive_mutex> lock(g.mu);
    stopLocked();
}

bool audioRunning() {
    std::lock_guard<std::recursive_mutex> lock(g.mu);
    return g.out != nullptr && AAudioStream_getState(g.out) == AAUDIO_STREAM_STATE_STARTED;
}

AudioStats audioStats() {
    std::lock_guard<std::recursive_mutex> lock(g.mu);
    AudioStats s;
    if (!g.out) return s;
    s.sampleRate = AAudioStream_getSampleRate(g.out);
    s.xruns = AAudioStream_getXRunCount(g.out);
    // Ajuste automático: se houver falhas (xruns), aumenta o buffer em um burst.
    if (s.xruns > g.lastXruns) {
        const int cur = AAudioStream_getBufferSizeInFrames(g.out);
        if (cur + g.burst <= g.maxBuffer) AAudioStream_setBufferSizeInFrames(g.out, cur + g.burst);
        g.lastXruns = s.xruns;
    }
    s.bufferFrames = AAudioStream_getBufferSizeInFrames(g.out);
    s.burstFrames = g.burst;
    const int inBurst = g.in ? AAudioStream_getFramesPerBurst(g.in) : g.burst;
    // saída (buffer) + entrada (1 burst) + atraso típico do conversor (~2 ms cada lado)
    s.latencyMs = s.sampleRate > 0 ? 1000.f * (s.bufferFrames + inBurst) / s.sampleRate + 4.f : 0.f;
    s.exclusive = AAudioStream_getSharingMode(g.out) == AAUDIO_SHARING_MODE_EXCLUSIVE &&
                  g.in && AAudioStream_getSharingMode(g.in) == AAUDIO_SHARING_MODE_EXCLUSIVE;
    return s;
}

}  // namespace rig
