// Pedais: dinâmica, drives, filtros, modulação, tempo e utilitários.
#include <cmath>

#include "dsp.h"
#include "effect.h"

namespace rig {
using namespace dsp;

namespace {

inline float knobLevelDb(float knob010) { return -26.f + knob010 * 4.f; }  // 5 -> -6 dB, 10 -> +14 dB

// ====================================================================== Noise Gate
class NoiseGate : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        env_.set(0.2f, 12.f, sr);
        att_ = 1.f - std::exp(-1.f / (0.0008f * sr));
        hold_ = static_cast<int>(0.04f * sr);
        update();
    }
    void reset() override { env_.reset(); gain_ = 0; open_ = false; }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float e = env_.process(b[i]);
            if (e > thrOpen_) { open_ = true; holdLeft_ = hold_; }
            else if (e < thrClose_) { if (holdLeft_ > 0) --holdLeft_; else open_ = false; }
            const float t = open_ ? 1.f : 0.f;
            gain_ += (t > gain_ ? att_ : rel_) * (t - gain_);
            b[i] *= gain_;
        }
    }
private:
    void update() {
        const float thr = param(0);
        thrOpen_ = dbToGain(thr);
        thrClose_ = dbToGain(thr - 6.f);
        rel_ = 1.f - std::exp(-1.f / std::max(1.f, param(1) * 0.001f * sr_));
    }
    EnvFollower env_;
    float thrOpen_ = 0, thrClose_ = 0, att_ = 0, rel_ = 0, gain_ = 0;
    int hold_ = 0, holdLeft_ = 0;
    bool open_ = false;
};

// ====================================================================== Compressor
class Compressor : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; update(); }
    void reset() override { env_ = 0; }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            const float a = std::fabs(x);
            env_ += (a > env_ ? att_ : rel_) * (a - env_);
            const float lvl = gainToDb(env_ + 1e-9f);
            const float over = lvl - thr_;
            float gr;
            constexpr float W = 6.f;
            if (over <= -W * 0.5f) gr = 0.f;
            else if (over < W * 0.5f) gr = slope_ * (over + W * 0.5f) * (over + W * 0.5f) / (2.f * W);
            else gr = slope_ * over;
            const float g = std::exp((makeup_ - gr) * 0.11512925f);
            b[i] = x * (1.f - blend_) + x * g * blend_;
        }
    }
private:
    void update() {
        thr_ = param(0);
        slope_ = 1.f - 1.f / std::max(1.f, param(1));
        att_ = 1.f - std::exp(-1.f / std::max(1.f, param(2) * 0.001f * sr_));
        rel_ = 1.f - std::exp(-1.f / std::max(1.f, param(3) * 0.001f * sr_));
        makeup_ = param(4);
        blend_ = clampf(param(5), 0.f, 1.f);
    }
    float env_ = 0, thr_ = -30, slope_ = 0.75f, att_ = 0, rel_ = 0, makeup_ = 0, blend_ = 1;
};

// ====================================================================== Clean Boost
class Boost : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; gain_.setTime(20, sr); update(); gain_.cur = gain_.target; }
    void reset() override { lo_.reset(); hi_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = hi_.process(lo_.process(b[i])) * gain_.next();
            b[i] = 1.5f * fastTanh(x * (1.f / 1.5f));
        }
    }
private:
    void update() {
        gain_.target = dbToGain(param(0));
        lo_.lowShelf(120, param(1), sr_);
        hi_.highShelf(3000, param(2), sr_);
    }
    Smoothed gain_;
    Biquad lo_, hi_;
};

// ====================================================================== Overdrive (estilo TS)
class GreenDrive : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        const float osr = sr * 4;
        inHp_.setCutoff(20, osr);
        hp720_.setCutoff(720, osr);
        level_.setTime(20, sr);
        update();
        level_.cur = level_.target;
    }
    void reset() override { os_.reset(); inHp_.reset(); hp720_.reset(); fbLp_.reset(); tone_.reset(); post_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        float u[4];
        for (int i = 0; i < n; ++i) {
            os_.up(b[i], u);
            for (float& s : u) {
                const float x = inHp_.process(s);
                const float v = fbLp_.process(hp720_.process(x) * gainPath_);
                s = x + 0.6f * fastTanh(v * (1.f / 0.6f));
            }
            const float y = os_.down(u);
            b[i] = post_.process(tone_.process(y)) * level_.next();
        }
    }
private:
    void update() {
        const float d = clampf(param(0) / 10.f, 0, 1);
        const float r = 500e3f * d * d;  // pot log
        gainPath_ = (51e3f + r) / 4.7e3f;
        fbLp_.setCutoff(std::min(1.f / (2 * kPi * (51e3f + r) * 51e-12f), sr_ * 1.8f), sr_ * 4);
        tone_.setCutoff(expMap(param(1) / 10.f, 700.f, 5500.f), sr_);
        post_.setCutoff(9000, sr_);
        level_.target = dbToGain(knobLevelDb(param(2)) - 12.f);
    }
    Oversampler4x os_;
    OnePoleHP inHp_, hp720_;
    OnePoleLP fbLp_, tone_, post_;
    Smoothed level_;
    float gainPath_ = 10;
};

// ====================================================================== Distorção (estilo RAT)
class RodentDist : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        const float osr = sr * 4;
        inHp_.setCutoff(20, osr);
        hp60_.setCutoff(60, osr);
        hp1k5_.setCutoff(1540, osr);
        level_.setTime(20, sr);
        update();
        level_.cur = level_.target;
    }
    void reset() override { os_.reset(); inHp_.reset(); hp60_.reset(); hp1k5_.reset(); gbw_.reset(); filt_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        float u[4];
        for (int i = 0; i < n; ++i) {
            os_.up(b[i], u);
            for (float& s : u) {
                const float x = inHp_.process(s);
                float v = x + hp60_.process(x) * g1_ + hp1k5_.process(x) * g2_;
                v = gbw_.process(v);
                s = 0.6f * hardKnee(v * (1.f / 0.6f));
            }
            b[i] = filt_.process(os_.down(u)) * level_.next();
        }
    }
private:
    void update() {
        const float d = clampf(param(0) / 10.f, 0, 1);
        const float r = 100e3f * d * d + 10.f;
        g1_ = r / 560.f;
        g2_ = r / 47.f;
        const float fc = clampf(1.5e6f / (1.f + g2_), 3000.f, 20000.f);
        gbw_.setCutoff(fc, sr_ * 4);
        filt_.setCutoff(expMap(1.f - param(1) / 10.f, 500.f, 20000.f), sr_);
        level_.target = dbToGain(knobLevelDb(param(2)) - 16.f);
    }
    Oversampler4x os_;
    OnePoleHP inHp_, hp60_, hp1k5_;
    OnePoleLP gbw_, filt_;
    Smoothed level_;
    float g1_ = 1, g2_ = 1;
};

// ====================================================================== Fuzz
class VintageFuzz : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        dc_.setCutoff(25, sr * 4);
        lp_.setCutoff(450, sr);
        hp_.setCutoff(1100, sr);
        level_.setTime(20, sr);
        update();
        level_.cur = level_.target;
    }
    void reset() override { os_.reset(); dc_.reset(); lp_.reset(); hp_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        float u[4];
        for (int i = 0; i < n; ++i) {
            os_.up(b[i], u);
            for (float& s : u) {
                const float v = s * drive_ + bias_;
                const float y = v > 0 ? fastTanh(v) : 0.55f * hardKnee(v * (1.f / 0.55f));
                s = dc_.process(y - biasOut_);
            }
            const float y = os_.down(u);
            const float l = lp_.process(y), h = hp_.process(y);
            b[i] = (l * (1.f - tone_) + h * tone_ * 1.6f) * level_.next();
        }
    }
private:
    void update() {
        const float f = clampf(param(0) / 10.f, 0, 1);
        drive_ = 3.f + f * f * 80.f;
        bias_ = 0.12f + 0.15f * f;
        biasOut_ = fastTanh(bias_);
        tone_ = clampf(param(1) / 10.f, 0, 1);
        level_.target = dbToGain(knobLevelDb(param(2)) - 12.f);
    }
    Oversampler4x os_;
    OnePoleHP dc_;
    OnePoleLP lp_;
    OnePoleHP hp_;
    Smoothed level_;
    float drive_ = 10, bias_ = 0.2f, biasOut_ = 0, tone_ = 0.5f;
};

// ====================================================================== Metal (alto ganho com EQ)
class MetalCore : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        const float osr = sr * 4;
        tight_.highpass(140, 0.707, osr);
        hp2_.setCutoff(90, osr);
        lp2_.setCutoff(7000, osr);
        post_.lowpass(6500, 0.707, sr);
        level_.setTime(20, sr);
        update();
        level_.cur = level_.target;
    }
    void reset() override { os_.reset(); tight_.reset(); hp2_.reset(); lp2_.reset(); lo_.reset(); mid_.reset(); hi_.reset(); post_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        float u[4];
        for (int i = 0; i < n; ++i) {
            os_.up(b[i], u);
            for (float& s : u) {
                float v = fastTanh(tight_.process(s) * g1_);
                v = lp2_.process(hp2_.process(v));
                s = 0.5f * hardKnee(v * 5.f);
            }
            float y = os_.down(u);
            y = post_.process(hi_.process(mid_.process(lo_.process(y))));
            b[i] = y * level_.next();
        }
    }
private:
    void update() {
        g1_ = dbToGain(6.f + param(0) * 3.6f);
        lo_.lowShelf(100, param(1), sr_);
        mid_.peak(clampf(param(3), 200, 4000), 0.8, param(2), sr_);
        hi_.highShelf(3500, param(4), sr_);
        level_.target = dbToGain(knobLevelDb(param(5)) - 14.f);
    }
    Oversampler4x os_;
    Biquad tight_;
    OnePoleHP hp2_;
    OnePoleLP lp2_;
    Biquad lo_, mid_, hi_, post_;
    Smoothed level_;
    float g1_ = 10;
};

// ====================================================================== EQ gráfico 7 bandas
class GraphicEq : public Effect {
public:
    static constexpr int kBands = 7;
    static constexpr float kFreq[kBands] = {100, 200, 400, 800, 1600, 3200, 6400};
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; level_.setTime(20, sr); update(); level_.cur = level_.target; }
    void reset() override { for (auto& f : f_) f.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            float x = b[i];
            for (auto& f : f_) x = f.process(x);
            b[i] = x * level_.next();
        }
    }
private:
    void update() {
        for (int k = 0; k < kBands; ++k) f_[k].peak(kFreq[k], 1.1, param(k), sr_);
        level_.target = dbToGain(param(7));
    }
    Biquad f_[kBands];
    Smoothed level_;
};
constexpr float GraphicEq::kFreq[GraphicEq::kBands];

// ====================================================================== Wah
class Wah : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        env_.set(4, 120, sr);
        pos_.setTime(15, sr);
        update();
        pos_.snap(param(1));
    }
    void reset() override { svf_.reset(); env_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            const float e = env_.process(x);
            pos_.target = autoMode_ ? clampf(e * sens_ * 30.f, 0.f, 1.f) : manual_;
            const float p = pos_.next();
            if ((counter_++ & 7) == 0) svf_.set(350.f * std::pow(2.f, p * 2.7f), q_, sr_);
            svf_.process(x);
            b[i] = 3.2f * svf_.k * svf_.bp + 0.25f * svf_.lp;
        }
    }
private:
    void update() {
        autoMode_ = param(0) >= 0.5f;
        manual_ = clampf(param(1), 0, 1);
        sens_ = clampf(param(2), 0, 1);
        q_ = clampf(param(3), 1, 12);
    }
    SVF svf_;
    EnvFollower env_;
    Smoothed pos_;
    bool autoMode_ = false;
    float manual_ = 0.5f, sens_ = 0.5f, q_ = 6;
    uint32_t counter_ = 0;
};

// ====================================================================== Chorus
class Chorus : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        line_.prepare(static_cast<int>(0.03f * sr));
        lp_.setCutoff(6500, sr);
        l2_.phase = 0.25f;
        update();
    }
    void reset() override { line_.reset(); lp_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            line_.push(x);
            const float d1 = (0.007f + depth_ * 0.0025f * (1.f + l1_.sine())) * sr_;
            const float d2 = (0.009f + depth_ * 0.0025f * (1.f + l2_.sine())) * sr_;
            const float wet = lp_.process(0.5f * (line_.read(d1) + line_.read(d2)));
            b[i] = ((1.f - mix_) * x + mix_ * wet) * (1.f + 0.5f * mix_);
        }
    }
private:
    void update() {
        l1_.set(param(0), sr_);
        l2_.set(param(0) * 1.13f, sr_);
        depth_ = clampf(param(1), 0, 1);
        mix_ = clampf(param(2), 0, 1);
    }
    DelayLine line_;
    LFO l1_, l2_;
    OnePoleLP lp_;
    float depth_ = 0.5f, mix_ = 0.5f;
};

// ====================================================================== Flanger
class Flanger : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; line_.prepare(static_cast<int>(0.012f * sr)); update(); }
    void reset() override { line_.reset(); fbState_ = 0; }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            const float d = (0.0003f + depth_ * 0.002f * (1.f + lfo_.tri())) * sr_;
            const float del = line_.read(std::max(1.f, d));
            line_.push(sanitize(x + fb_ * del));
            b[i] = (1.f - mix_) * x + mix_ * del;
        }
    }
private:
    void update() {
        lfo_.set(param(0), sr_);
        depth_ = clampf(param(1), 0, 1);
        fb_ = clampf(param(2), -0.95f, 0.95f);
        mix_ = clampf(param(3), 0, 1);
    }
    DelayLine line_;
    LFO lfo_;
    float depth_ = 0.7f, fb_ = 0.5f, mix_ = 0.5f, fbState_ = 0;
};

// ====================================================================== Phaser
class Phaser : public Effect {
public:
    static constexpr int kMaxStages = 12;
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; update(); }
    void reset() override { for (float& z : z_) z = 0; last_ = 0; }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float l = lfo_.sine();
            if ((counter_++ & 3) == 0) {
                const float t = 0.5f + 0.5f * l * depth_;
                const float fc = 180.f * std::pow(10.f, t);
                const float tn = std::tan(kPi * fc / sr_);
                a_ = (tn - 1.f) / (tn + 1.f);
            }
            const float x = b[i];
            float s = x + fb_ * last_;
            for (int k = 0; k < stages_; ++k) {
                const float y = a_ * s + z_[k];
                z_[k] = s - a_ * y;
                s = y;
            }
            last_ = sanitize(s);
            b[i] = (1.f - mix_) * x + mix_ * s;
        }
    }
private:
    void update() {
        lfo_.set(param(0), sr_);
        depth_ = clampf(param(1), 0, 1);
        fb_ = clampf(param(2), 0, 0.9f);
        static const int st[4] = {4, 6, 8, 12};
        stages_ = st[static_cast<int>(clampf(param(3), 0, 3) + 0.5f)];
        mix_ = clampf(param(4), 0, 1);
    }
    LFO lfo_;
    float z_[kMaxStages] = {};
    float a_ = 0, depth_ = 0.7f, fb_ = 0.4f, mix_ = 0.5f, last_ = 0;
    int stages_ = 4;
    uint32_t counter_ = 0;
};

// ====================================================================== Tremolo
class Tremolo : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; update(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float s = fastTanh(lfo_.sine() * shapeK_) * shapeNorm_;
            b[i] *= 1.f - depth_ * (0.5f - 0.5f * s);
        }
    }
private:
    void update() {
        lfo_.set(param(0), sr_);
        depth_ = clampf(param(1), 0, 1);
        shapeK_ = 0.3f + clampf(param(2), 0, 1) * 8.f;
        shapeNorm_ = 1.f / fastTanh(shapeK_);
    }
    LFO lfo_;
    float depth_ = 0.6f, shapeK_ = 1, shapeNorm_ = 1;
};

// ====================================================================== Vibrato
class Vibrato : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; line_.prepare(static_cast<int>(0.012f * sr)); update(); }
    void reset() override { line_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            line_.push(b[i]);
            b[i] = line_.read((0.002f + depth_ * 0.003f * (0.5f + 0.5f * lfo_.sine())) * sr_);
        }
    }
private:
    void update() { lfo_.set(param(0), sr_); depth_ = clampf(param(1), 0, 1); }
    DelayLine line_;
    LFO lfo_;
    float depth_ = 0.3f;
};

// ====================================================================== Octaver (divisor analógico)
class Octaver : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        lp1_.lowpass(350, 0.707, sr);
        lp2_.lowpass(350, 0.707, sr);
        env_.set(2, 60, sr);
        gate_.setTime(10, sr);
        update();
    }
    void reset() override { lp1_.reset(); lp2_.reset(); tone_.reset(); env_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            const float s = lp2_.process(lp1_.process(x));
            const float e = env_.process(s);
            const float thr = 0.15f * e;
            if (!pos_ && s > thr) {
                pos_ = true;
                ff1_ = -ff1_;
                if (ff1_ > 0) ff2_ = -ff2_;
            } else if (pos_ && s < -thr) {
                pos_ = false;
            }
            gate_.target = e > 0.002f ? 1.f : 0.f;
            const float sub = (o1_ * ff1_ + o2_ * ff2_) * s * 2.5f * gate_.next();
            b[i] = dry_ * x + tone_.process(sub);
        }
    }
private:
    void update() {
        dry_ = clampf(param(0), 0, 1);
        o1_ = clampf(param(1), 0, 1);
        o2_ = clampf(param(2), 0, 1);
        tone_.lowpass(expMap(param(3), 150, 1500), 0.707, sr_);
    }
    Biquad lp1_, lp2_, tone_;
    EnvFollower env_;
    Smoothed gate_;
    bool pos_ = false;
    float ff1_ = 1, ff2_ = 1, dry_ = 0.7f, o1_ = 0.6f, o2_ = 0;
};

// ====================================================================== Delay
class Delay : public Effect {
public:
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        line_.prepare(static_cast<int>(2.6f * sr));
        time_.setTime(60, sr);
        hp_.setCutoff(80, sr);
        wow_.set(0.6f, sr);
        flutter_.set(7.0f, sr);
        update();
        time_.snap(time_.target);
    }
    void reset() override { line_.reset(); lp_.reset(); hp_.reset(); }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            float d = time_.next();
            if (mode_ == 2) d += (0.0012f * wow_.sine() + 0.00015f * flutter_.sine()) * sr_;
            else if (mode_ == 1) d += 0.0002f * wow_.sine() * sr_;
            float r = lp_.process(line_.read(std::max(2.f, d)));
            if (mode_ > 0) r = hp_.process(r);
            float fb = r * fb_;
            if (mode_ > 0) fb = fastTanh(fb * 1.3f) * (1.f / 1.3f);
            line_.push(sanitize(x + fb));
            b[i] = x + mix_ * r;
        }
    }
private:
    void update() {
        mode_ = static_cast<int>(clampf(param(4), 0, 2) + 0.5f);
        time_.target = clampf(param(0), 20, 2000) * 0.001f * sr_;
        fb_ = clampf(param(1), 0, 0.95f);
        mix_ = clampf(param(2), 0, 1);
        const float t = clampf(param(3), 0, 1);
        const float fc = mode_ == 0 ? expMap(t, 2000, 16000) : mode_ == 1 ? expMap(t, 1000, 5000) : expMap(t, 1500, 7000);
        lp_.setCutoff(fc, sr_);
    }
    DelayLine line_;
    Smoothed time_;
    OnePoleLP lp_;
    OnePoleHP hp_;
    LFO wow_, flutter_;
    int mode_ = 0;
    float fb_ = 0.35f, mix_ = 0.3f;
};

// ====================================================================== Reverb (FDN 8 linhas)
class Reverb : public Effect {
public:
    static constexpr int kLines = 8;
    void prepare(float sr, int mb) override {
        sr_ = sr; maxBlock_ = mb;
        const float k = sr / 48000.f;
        for (auto& l : lines_) l.prepare(static_cast<int>(3200 * 2.3f * k) + 64);
        for (auto& a : ap_) a.prepare(static_cast<int>(450 * k * 1.1f) + 8);
        pre_.prepare(static_cast<int>(0.21f * sr));
        m1_.set(0.53f, sr);
        m2_.set(0.79f, sr);
        inLp_.setCutoff(9000, sr);
        update();
    }
    void reset() override {
        for (auto& l : lines_) l.reset();
        for (auto& a : ap_) a.reset();
        for (auto& d : damp_) d.reset();
        pre_.reset();
    }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) {
            const float x = b[i];
            pre_.push(inLp_.process(x));
            float in = pre_.read(std::max(1.f, preSamples_));
            for (int a = 0; a < 4; ++a) {
                const float d = ap_[a].readInt(apLen_[a]);
                const float v = in + apG_ * d;
                ap_[a].push(v);
                in = d - apG_ * v;
            }
            float s[kLines];
            float sum = 0;
            const float mod1 = 6.f * m1_.sine(), mod2 = 6.f * m2_.sine();
            for (int l = 0; l < kLines; ++l) {
                float len = len_[l];
                if (l == 0) len += mod1;
                if (l == 5) len += mod2;
                s[l] = damp_[l].process(lines_[l].read(len));
                sum += s[l] * g_[l];
            }
            float wet = 0;
            const float h = sum * (2.f / kLines);
            for (int l = 0; l < kLines; ++l) {
                const float f = s[l] * g_[l] - h;
                lines_[l].push(sanitize(f + in * ((l & 1) ? 0.5f : -0.5f)));
                wet += (l & 2) ? s[l] : -s[l];
            }
            b[i] = x * (1.f - 0.3f * mix_) + wet * 0.45f * mix_;
        }
    }
private:
    void update() {
        mode_ = static_cast<int>(clampf(param(0), 0, 2) + 0.5f);
        static const float room[kLines] = {593, 709, 829, 947, 1069, 1193, 1307, 1427};
        static const float plate[kLines] = {431, 487, 557, 617, 691, 751, 827, 883};
        static const float apBase[4] = {142, 107, 379, 277};
        const float k = sr_ / 48000.f;
        const float scale = mode_ == 1 ? 2.2f : 1.0f;
        const float* base = mode_ == 2 ? plate : room;
        const float t60 = clampf(param(1), 0.2f, 10.f);
        for (int l = 0; l < kLines; ++l) {
            len_[l] = base[l] * scale * k;
            g_[l] = std::pow(10.f, -3.f * len_[l] / (t60 * sr_));
            damp_[l].setCutoff(expMap(param(3), 1500, 12000), sr_);
        }
        for (int a = 0; a < 4; ++a) apLen_[a] = std::max(1, static_cast<int>(apBase[a] * k * (mode_ == 2 ? 1.1f : 1.0f)));
        apG_ = mode_ == 2 ? 0.72f : 0.62f;
        preSamples_ = clampf(param(2), 0, 200) * 0.001f * sr_;
        mix_ = clampf(param(4), 0, 1);
    }
    DelayLine lines_[kLines];
    DelayLine ap_[4];
    DelayLine pre_;
    OnePoleLP damp_[kLines];
    OnePoleLP inLp_;
    LFO m1_, m2_;
    float len_[kLines] = {}, g_[kLines] = {};
    int apLen_[4] = {1, 1, 1, 1};
    float apG_ = 0.6f, preSamples_ = 0, mix_ = 0.25f;
    int mode_ = 0;
};

// ====================================================================== Volume
class Volume : public Effect {
public:
    void prepare(float sr, int mb) override { sr_ = sr; maxBlock_ = mb; g_.setTime(25, sr); update(); g_.cur = g_.target; }
    void process(float* b, int n) override {
        if (consumeDirty()) update();
        for (int i = 0; i < n; ++i) b[i] *= g_.next();
    }
private:
    void update() { g_.target = param(0) <= -59.9f ? 0.f : dbToGain(param(0)); }
    Smoothed g_;
};

template <class T>
std::function<Effect*(int)> maker() {
    return [](int) -> Effect* { return new T(); };
}

ParamDef knob(const char* name, float def = 5.f) { return {name, 0.f, 10.f, def, "", 0, {}}; }
ParamDef p(const char* name, float mn, float mx, float def, const char* unit) { return {name, mn, mx, def, unit, 0, {}}; }
ParamDef sw(const char* name, std::vector<std::string> labels, float def = 0) {
    const int n = static_cast<int>(labels.size());
    return {name, 0.f, static_cast<float>(n - 1), def, "", n, std::move(labels)};
}

}  // namespace

void registerPedals(std::vector<BlockDef>& out) {
    out.push_back({"gate", "Noise Gate", "pedal", "Dinâmica", "#2B2D33",
                   "Corta o chiado entre as notas. Coloque no início da cadeia.",
                   {p("Limiar", -90, -20, -60, "dB"), p("Liberação", 5, 500, 100, "ms")}, {}, maker<NoiseGate>()});
    out.push_back({"comp", "Compressor", "pedal", "Dinâmica", "#1F5FAF",
                   "Nivela a dinâmica e aumenta a sustentação.",
                   {p("Limiar", -60, 0, -30, "dB"), p("Razão", 1, 20, 4, ":1"), p("Ataque", 0.1f, 100, 5, "ms"),
                    p("Liberação", 10, 1000, 120, "ms"), p("Ganho", 0, 30, 8, "dB"), p("Mistura", 0, 1, 1, "%")},
                   {}, maker<Compressor>()});
    out.push_back({"boost", "Clean Boost", "pedal", "Drive", "#C9C9C9",
                   "Reforço limpo de volume com graves e agudos.",
                   {p("Ganho", 0, 20, 8, "dB"), p("Graves", -10, 10, 0, "dB"), p("Agudos", -10, 10, 0, "dB")}, {}, maker<Boost>()});
    out.push_back({"od_green", "Green Drive", "pedal", "Drive", "#2F8F4E",
                   "Overdrive de médios acentuados, clássico para empurrar o amplificador.",
                   {knob("Drive"), knob("Tom"), knob("Nível")}, {}, maker<GreenDrive>()});
    out.push_back({"dist_rodent", "Rodent Dist", "pedal", "Drive", "#1C1C1C",
                   "Distorção com op-amp e diodos ao terra. O filtro escurece o som.",
                   {knob("Distorção"), knob("Filtro", 4), knob("Nível")}, {}, maker<RodentDist>()});
    out.push_back({"fuzz", "Vintage Fuzz", "pedal", "Drive", "#B3362C",
                   "Fuzz de transistor assimétrico, gordo e com sustain.",
                   {knob("Fuzz", 7), knob("Tom"), knob("Nível")}, {}, maker<VintageFuzz>()});
    out.push_back({"metal", "Metal Core", "pedal", "Drive", "#3A3A3A",
                   "Distorção de alto ganho com EQ de três bandas e médio ajustável.",
                   {knob("Ganho", 7), p("Graves", -12, 12, 2, "dB"), p("Médios", -12, 12, -4, "dB"),
                    p("Freq. médios", 200, 4000, 800, "Hz"), p("Agudos", -12, 12, 2, "dB"), knob("Nível")},
                   {}, maker<MetalCore>()});
    out.push_back({"geq", "EQ Gráfico", "pedal", "Filtro", "#E3E3E3",
                   "Equalizador de 7 bandas.",
                   {p("100", -12, 12, 0, "dB"), p("200", -12, 12, 0, "dB"), p("400", -12, 12, 0, "dB"),
                    p("800", -12, 12, 0, "dB"), p("1.6k", -12, 12, 0, "dB"), p("3.2k", -12, 12, 0, "dB"),
                    p("6.4k", -12, 12, 0, "dB"), p("Nível", -12, 12, 0, "dB")},
                   {}, maker<GraphicEq>()});
    out.push_back({"wah", "Wah", "pedal", "Filtro", "#222222",
                   "Wah manual (arraste o pedal) ou automático (segue a palhetada).",
                   {sw("Modo", {"Manual", "Auto"}), p("Pedal", 0, 1, 0.5f, "%"), p("Sensibilidade", 0, 1, 0.5f, "%"),
                    p("Ressonância", 1, 12, 6, "")},
                   {}, maker<Wah>()});
    out.push_back({"octave", "Octaver", "pedal", "Filtro", "#6A3FA0",
                   "Oitavas abaixo (-1 e -2). Funciona melhor com notas isoladas.",
                   {p("Direto", 0, 1, 0.7f, "%"), p("Oitava -1", 0, 1, 0.6f, "%"), p("Oitava -2", 0, 1, 0, "%"),
                    p("Tom", 0, 1, 0.4f, "%")},
                   {}, maker<Octaver>()});
    out.push_back({"chorus", "Chorus", "pedal", "Modulação", "#3FA7C9",
                   "Chorus de duas vozes com toque analógico.",
                   {p("Velocidade", 0.05f, 5, 0.8f, "Hz"), p("Profundidade", 0, 1, 0.5f, "%"), p("Mistura", 0, 1, 0.5f, "%")},
                   {}, maker<Chorus>()});
    out.push_back({"flanger", "Flanger", "pedal", "Modulação", "#8E44AD",
                   "Efeito de jato com realimentação positiva ou negativa.",
                   {p("Velocidade", 0.05f, 5, 0.3f, "Hz"), p("Profundidade", 0, 1, 0.7f, "%"),
                    p("Realimentação", -0.95f, 0.95f, 0.5f, ""), p("Mistura", 0, 1, 0.5f, "%")},
                   {}, maker<Flanger>()});
    out.push_back({"phaser", "Phaser", "pedal", "Modulação", "#E67E22",
                   "Phaser de 4 a 12 estágios.",
                   {p("Velocidade", 0.05f, 5, 0.5f, "Hz"), p("Profundidade", 0, 1, 0.7f, "%"),
                    p("Realimentação", 0, 0.9f, 0.4f, ""), sw("Estágios", {"4", "6", "8", "12"}), p("Mistura", 0, 1, 0.5f, "%")},
                   {}, maker<Phaser>()});
    out.push_back({"tremolo", "Tremolo", "pedal", "Modulação", "#D4AC0D",
                   "Variação de volume, de suave (seno) a picotado (quadrada).",
                   {p("Velocidade", 0.5f, 15, 5, "Hz"), p("Profundidade", 0, 1, 0.6f, "%"), p("Forma", 0, 1, 0.2f, "%")},
                   {}, maker<Tremolo>()});
    out.push_back({"vibrato", "Vibrato", "pedal", "Modulação", "#16A085",
                   "Modulação de afinação 100% molhada.",
                   {p("Velocidade", 0.5f, 10, 5, "Hz"), p("Profundidade", 0, 1, 0.3f, "%")}, {}, maker<Vibrato>()});
    out.push_back({"delay", "Delay", "pedal", "Tempo", "#2E86C1",
                   "Delay digital, analógico (escuro e saturado) ou de fita (com wow & flutter).",
                   {p("Tempo", 20, 2000, 380, "ms"), p("Repetições", 0, 0.95f, 0.35f, "%"), p("Mistura", 0, 1, 0.3f, "%"),
                    p("Tom", 0, 1, 0.6f, "%"), sw("Tipo", {"Digital", "Analógico", "Fita"})},
                   {}, maker<Delay>()});
    out.push_back({"reverb", "Reverb", "pedal", "Tempo", "#5D6D7E",
                   "Reverberação de sala, salão ou placa.",
                   {sw("Tipo", {"Sala", "Salão", "Placa"}), p("Decaimento", 0.2f, 10, 1.8f, "s"), p("Pré-atraso", 0, 200, 15, "ms"),
                    p("Tom", 0, 1, 0.5f, "%"), p("Mistura", 0, 1, 0.25f, "%")},
                   {}, maker<Reverb>()});
    out.push_back({"volume", "Volume", "pedal", "Utilitário", "#4A4A4A",
                   "Pedal de volume.", {p("Nível", -60, 12, 0, "dB")}, {}, maker<Volume>()});
}

}  // namespace rig
