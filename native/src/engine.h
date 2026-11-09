// Motor: cadeia de blocos, roteamento, medidores, afinador e looper.
//
// Modelo de threads:
//  * Funções públicas (exceto processAudio) são chamadas pela UI e serializadas
//    por mutex_. Elas nunca bloqueiam a thread de áudio.
//  * A cadeia ativa é um ponteiro atômico para uma lista imutável. Mudanças criam
//    uma nova lista, trocam o ponteiro e liberam a antiga só depois que a thread
//    de áudio completou um ciclo (waitForAudioCycle).
#pragma once

#include <atomic>
#include <cmath>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "convolver.h"
#include "effect.h"
#include "tuner.h"

namespace rig {

class Looper {
public:
    enum State { kEmpty = 0, kRecording = 1, kPlaying = 2, kOverdub = 3, kStopped = 4 };
    enum Cmd { kNone = 0, kMain = 1, kStop = 2, kClear = 3, kPlay = 4 };

    void prepare(float sr);
    void process(float* buf, int n);  // thread de áudio
    void command(int c) { cmd_.store(c, std::memory_order_release); }
    int state() const { return stateOut_.load(std::memory_order_relaxed); }
    float progress() const { return progress_.load(std::memory_order_relaxed); }
    float lengthSec() const { return lengthSec_.load(std::memory_order_relaxed); }
    void setLevel(float l) { level_.store(l, std::memory_order_relaxed); }

private:
    void finishRecording();
    std::vector<float> buf_;
    int len_ = 0, pos_ = 0, state_ = kEmpty;
    float sr_ = 48000;
    std::atomic<int> cmd_{kNone};
    std::atomic<int> stateOut_{kEmpty};
    std::atomic<float> progress_{0}, lengthSec_{0}, level_{1.f};
};

class Engine {
public:
    static Engine& instance();

    // ---- cadeia (UI)
    int addBlock(const std::string& typeId, int model, int index);  // >0 id, <0 erro
    bool removeBlock(int id);
    bool moveBlock(int id, int newIndex);
    void clearChain();
    void setParam(int id, int index, float value);
    void setBypass(int id, bool bypass);
    int loadIr(int id, const std::string& path, std::string& err);
    void clearIr(int id);
    int blockCount();

    // ---- global (UI)
    void setInputGainDb(float db) { inGain_.store(db <= -59.9f ? 0.f : std::pow(10.f, db / 20.f)); }
    void setOutputGainDb(float db) { outGain_.store(db <= -59.9f ? 0.f : std::pow(10.f, db / 20.f)); }
    float takeInputPeak() { return inPeak_.exchange(0.f); }
    float takeOutputPeak() { return outPeak_.exchange(0.f); }
    void setTuner(bool on, bool mute) { tunerOn_.store(on); tunerMute_.store(mute); }
    float tunerFrequency() { return tuner_.estimate(); }
    Looper& looper() { return looper_; }

    // ---- ciclo de vida do áudio
    // Chamado com o fluxo de áudio PARADO: reconfigura todos os blocos.
    void configure(float sampleRate, int maxBlock);
    float sampleRate() const { return sr_; }
    void setRunning(bool r) { running_.store(r); }
    bool running() const { return running_.load(); }

    // Thread de áudio: in mono (pode ser nullptr = silêncio), out intercalado.
    void processAudio(const float* in, float* out, int frames, int outChannels);
    // Processamento offline (testes / sem fluxo ativo).
    void processOffline(const float* in, float* out, int frames);

private:
    Engine();
    struct Chain { std::vector<Effect*> fx; };
    void publishLocked();
    bool waitForAudioCycle();
    void processChain(Chain* c, float* buf, int n);
    void freeGraveyards();

    std::mutex mutex_;
    std::map<int, std::unique_ptr<Effect>> blocks_;
    std::vector<int> order_;
    std::vector<std::unique_ptr<Effect>> graveyard_;  // liberados quando o áudio parar
    std::vector<Chain*> chainGraveyard_;
    std::vector<Convolver*> convGraveyard_;
    int nextId_ = 1;

    std::atomic<Chain*> chain_{nullptr};
    std::atomic<bool> running_{false};
    std::atomic<uint64_t> cycles_{0};

    float sr_ = 48000.f;
    int maxBlock_ = 1024;
    std::vector<float> mono_, dry_;

    std::atomic<float> inGain_{1.f}, outGain_{1.f};
    float inGainCur_ = 1.f, outGainCur_ = 1.f;
    std::atomic<float> inPeak_{0.f}, outPeak_{0.f};
    std::atomic<bool> tunerOn_{false}, tunerMute_{false};
    float muteCur_ = 1.f;
    Tuner tuner_;
    Looper looper_;
};

}  // namespace rig
