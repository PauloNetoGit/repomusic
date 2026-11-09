// API C exportada para o Dart (dart:ffi). Todas as funções são chamadas pela
// isolate principal do Flutter; nenhuma delas bloqueia a thread de áudio.
#include <cstdint>
#include <mutex>
#include <string>

#include "audio.h"
#include "effect.h"
#include "engine.h"

#define AE_API extern "C" __attribute__((visibility("default"))) __attribute__((used))

namespace {
std::mutex g_errMu;
std::string g_err;
void setErr(const std::string& e) { std::lock_guard<std::mutex> l(g_errMu); g_err = e; }
rig::Engine& E() { return rig::Engine::instance(); }
}  // namespace

AE_API const char* ae_catalog_json() {
    static const std::string json = rig::catalogJson();
    return json.c_str();
}

AE_API const char* ae_last_error() {
    static thread_local std::string copy;
    std::lock_guard<std::mutex> l(g_errMu);
    copy = g_err;
    return copy.c_str();
}

// ------------------------------------------------------------------ áudio
AE_API int32_t ae_start(int32_t inputDevice, int32_t outputDevice) {
    std::string err;
    const int r = rig::audioStart(inputDevice, outputDevice, err);
    setErr(err);
    return r;
}
AE_API void ae_stop() { rig::audioStop(); }
AE_API int32_t ae_is_running() { return rig::audioRunning() ? 1 : 0; }

// out[0]=sampleRate out[1]=latênciaMs out[2]=xruns out[3]=bufferFrames out[4]=burst out[5]=exclusivo
AE_API void ae_get_stats(double* out, int32_t n) {
    const rig::AudioStats s = rig::audioStats();
    const double v[6] = {static_cast<double>(s.sampleRate), s.latencyMs, static_cast<double>(s.xruns),
                         static_cast<double>(s.bufferFrames), static_cast<double>(s.burstFrames), s.exclusive ? 1.0 : 0.0};
    for (int i = 0; i < n && i < 6; ++i) out[i] = v[i];
}

// ------------------------------------------------------------------ cadeia
AE_API int32_t ae_add_block(const char* typeId, int32_t model, int32_t index) {
    return E().addBlock(typeId ? typeId : "", model, index);
}
AE_API int32_t ae_remove_block(int32_t id) { return E().removeBlock(id) ? 1 : 0; }
AE_API int32_t ae_move_block(int32_t id, int32_t newIndex) { return E().moveBlock(id, newIndex) ? 1 : 0; }
AE_API void ae_clear_chain() { E().clearChain(); }
AE_API int32_t ae_block_count() { return E().blockCount(); }
AE_API void ae_set_param(int32_t id, int32_t index, float value) { E().setParam(id, index, value); }
AE_API void ae_set_bypass(int32_t id, int32_t bypass) { E().setBypass(id, bypass != 0); }

AE_API int32_t ae_load_ir(int32_t id, const char* path) {
    std::string err;
    const int r = E().loadIr(id, path ? path : "", err);
    setErr(err);
    return r;
}
AE_API void ae_clear_ir(int32_t id) { E().clearIr(id); }

// ------------------------------------------------------------------ global
AE_API void ae_set_input_gain_db(float db) { E().setInputGainDb(db); }
AE_API void ae_set_output_gain_db(float db) { E().setOutputGainDb(db); }
AE_API float ae_take_input_peak() { return E().takeInputPeak(); }
AE_API float ae_take_output_peak() { return E().takeOutputPeak(); }

AE_API void ae_tuner_set(int32_t on, int32_t mute) { E().setTuner(on != 0, mute != 0); }
AE_API float ae_tuner_frequency() { return E().tunerFrequency(); }

AE_API void ae_looper_command(int32_t cmd) { E().looper().command(cmd); }
AE_API int32_t ae_looper_state() { return E().looper().state(); }
AE_API float ae_looper_progress() { return E().looper().progress(); }
AE_API float ae_looper_length() { return E().looper().lengthSec(); }
AE_API void ae_looper_level(float level) { E().looper().setLevel(level); }

// ------------------------------------------------------------------ offline
// Processa um buffer mono sem fluxo ativo (testes e renderização).
AE_API int32_t ae_process_offline(const float* in, float* out, int32_t frames, int32_t sampleRate) {
    if (E().running()) return -1;
    if (sampleRate > 0 && static_cast<float>(sampleRate) != E().sampleRate()) E().configure(static_cast<float>(sampleRate), 1024);
    E().processOffline(in, out, frames);
    return frames;
}
