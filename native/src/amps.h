// Amplificadores, caixas e cubos (combos).
#pragma once

#include <atomic>
#include <vector>

#include "convolver.h"
#include "dsp.h"
#include "effect.h"

namespace rig {

struct TonestackValues {
    double R1, R2, R3, R4, C1, C2, C3;
};

// Tonestack passivo clássico (Fender/Marshall/Vox), modelado a partir do circuito
// (Yeh & Smith) e discretizado com transformada bilinear.
class Tonestack {
public:
    void set(const TonestackValues& v, float treble, float mid, float bass, float sr);
    inline float process(float x) { return f_.process(x); }
    void reset() { f_.reset(); }
    double magnitude(double f, double sr) const { return f_.magnitude(f, sr); }
private:
    dsp::ThirdOrder f_;
};

struct AmpModel {
    const char* name;
    const char* desc;
    float preHp;          // Hz, corte de graves na entrada
    float preLowDb;       // shelf de graves pré-ganho (200 Hz)
    float brightDb;       // shelf de agudos pré-ganho (2.5 kHz)
    int stages;           // estágios de pré-amplificação
    float gainMinDb, gainMaxDb;
    float stageGainDb;    // ganho entre estágios
    float bias;           // assimetria (harmônicos pares)
    float stageLp, stageHp;
    TonestackValues ts;
    float powerDb;        // drive na válvula de potência com Master = 5
    float sag;
    float resonanceDb;    // reforço de graves do power amp (100 Hz)
    bool solidState;
    float outTrimDb;      // calibração de volume entre modelos
};

const std::vector<AmpModel>& ampModels();

class AmpEffect : public Effect {
public:
    explicit AmpEffect(int modelIndex);
    void prepare(float sr, int maxBlock) override;
    void process(float* buf, int n) override;
    void reset() override;
    const AmpModel& def() const { return m_; }
private:
    void update();
    inline float stage(float x) const;
    AmpModel m_;
    dsp::Oversampler4x osPre_, osPow_;
    dsp::OnePoleHP inHp_;
    dsp::Biquad lowShelf_, bright_;
    dsp::OnePoleHP stHp_[6];
    dsp::OnePoleLP stLp_[6];
    Tonestack ts_;
    dsp::Biquad presence_, resonance_;
    dsp::OnePoleLP sagEnv_;
    dsp::Smoothed preGain_, powGain_, outGain_;
    float stageGain_ = 1, dc_ = 0;
};

struct CabModel {
    const char* name;
    const char* desc;
    struct Band { int type; float f, q, db; };  // type: 0 HP, 1 LP, 2 peak
    std::vector<Band> bands;
};

const std::vector<CabModel>& cabModels();
int irCabModelIndex();

class CabEffect : public Effect {
public:
    explicit CabEffect(int modelIndex);
    ~CabEffect() override;
    void prepare(float sr, int maxBlock) override;
    void process(float* buf, int n) override;
    void reset() override;

    // Somente fora da thread de áudio: monta um novo convolvedor. O motor
    // publica com swapConvolver() e libera o antigo depois que o áudio passou.
    Convolver* buildConvolver(const std::vector<float>& raw, float rawSr);
    Convolver* swapConvolver(Convolver* c) { return conv_.exchange(c, std::memory_order_acq_rel); }
    void setRawIr(const std::vector<float>& raw, float rawSr) { rawIr_ = raw; rawSr_ = rawSr; }
    bool hasIr() const { return !rawIr_.empty(); }
    void clearRawIr() { rawIr_.clear(); }
    static constexpr int kMaxIrLen = 8192;

private:
    void update();
    void designModel();
    std::vector<dsp::Biquad> eq_;
    dsp::Biquad mic_, micLp_, lowCut_, highCut_;
    dsp::Smoothed level_;
    float norm_ = 1;
    std::atomic<Convolver*> conv_{nullptr};
    std::vector<float> rawIr_;
    float rawSr_ = 48000;
};

class ComboEffect : public Effect {
public:
    explicit ComboEffect(int modelIndex);
    void prepare(float sr, int maxBlock) override;
    void process(float* buf, int n) override;
    void reset() override;
private:
    AmpEffect amp_;
    CabEffect cab_;
};

void registerAmps(std::vector<BlockDef>& out);

}  // namespace rig
