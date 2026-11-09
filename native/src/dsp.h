// Primitivas de DSP usadas por todos os blocos.
// Tudo aqui é seguro para a thread de áudio depois de prepare(): nada aloca memória
// dentro de process().
#pragma once

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstdint>
#include <cstring>
#include <vector>

namespace dsp {

constexpr float kPi = 3.14159265358979323846f;
constexpr double kPiD = 3.14159265358979323846;

inline float clampf(float x, float lo, float hi) { return x < lo ? lo : (x > hi ? hi : x); }
inline float dbToGain(float db) { return std::pow(10.0f, db * 0.05f); }
inline float gainToDb(float g) { return 20.0f * std::log10(std::max(g, 1e-9f)); }
inline float lerp(float a, float b, float t) { return a + (b - a) * t; }
// Mapeamento exponencial 0..1 -> [lo, hi]
inline float expMap(float t, float lo, float hi) { return lo * std::pow(hi / lo, clampf(t, 0.f, 1.f)); }

// tanh racional (erro < 2% e derivada contínua), saturando em +-1.
inline float fastTanh(float x) {
    if (x > 3.0f) return 1.0f;
    if (x < -3.0f) return -1.0f;
    const float x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

// Clipping "duro com joelho": mais agressivo que tanh, típico de diodos ao terra.
inline float hardKnee(float x) { return x / std::sqrt(std::sqrt(1.0f + x * x * x * x)); }

inline float sanitize(float x) {
    // Evita denormais e NaN/Inf propagando pela cadeia.
    if (!(std::fabs(x) < 1e6f)) return 0.0f;
    return std::fabs(x) < 1e-20f ? 0.0f : x;
}

// ---------------------------------------------------------------- filtros
struct OnePoleLP {
    float a = 1.f, z = 0.f;
    void setCutoff(float fc, float sr) { a = 1.0f - std::exp(-2.0f * kPi * std::min(fc, sr * 0.49f) / sr); }
    inline float process(float x) { z += a * (x - z); return z; }
    void reset() { z = 0.f; }
};

struct OnePoleHP {
    OnePoleLP lp;
    void setCutoff(float fc, float sr) { lp.setCutoff(fc, sr); }
    inline float process(float x) { return x - lp.process(x); }
    void reset() { lp.reset(); }
};

// Biquad em forma direta II transposta, coeficientes/estado em double para
// estabilidade em frequências baixas com taxas sobreamostradas.
struct Biquad {
    double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
    double z1 = 0, z2 = 0;

    inline float process(float xf) {
        const double x = xf;
        const double y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        return static_cast<float>(y);
    }
    void reset() { z1 = z2 = 0; }

    void setNorm(double nb0, double nb1, double nb2, double na0, double na1, double na2) {
        b0 = nb0 / na0; b1 = nb1 / na0; b2 = nb2 / na0; a1 = na1 / na0; a2 = na2 / na0;
    }
    static double w0(double f, double sr) { return 2.0 * kPiD * std::min(f, sr * 0.49) / sr; }

    void lowpass(double f, double q, double sr) {
        const double w = w0(f, sr), c = std::cos(w), al = std::sin(w) / (2 * q);
        setNorm((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + al, -2 * c, 1 - al);
    }
    void highpass(double f, double q, double sr) {
        const double w = w0(f, sr), c = std::cos(w), al = std::sin(w) / (2 * q);
        setNorm((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + al, -2 * c, 1 - al);
    }
    void bandpass(double f, double q, double sr) {  // ganho de pico 0 dB
        const double w = w0(f, sr), c = std::cos(w), al = std::sin(w) / (2 * q);
        setNorm(al, 0, -al, 1 + al, -2 * c, 1 - al);
    }
    void peak(double f, double q, double gainDb, double sr) {
        const double A = std::pow(10.0, gainDb / 40.0);
        const double w = w0(f, sr), c = std::cos(w), al = std::sin(w) / (2 * q);
        setNorm(1 + al * A, -2 * c, 1 - al * A, 1 + al / A, -2 * c, 1 - al / A);
    }
    void lowShelf(double f, double gainDb, double sr, double s = 1.0) {
        const double A = std::pow(10.0, gainDb / 40.0);
        const double w = w0(f, sr), c = std::cos(w), sn = std::sin(w);
        const double al = sn / 2 * std::sqrt((A + 1 / A) * (1 / s - 1) + 2);
        const double sq = 2 * std::sqrt(A) * al;
        setNorm(A * ((A + 1) - (A - 1) * c + sq), 2 * A * ((A - 1) - (A + 1) * c),
                A * ((A + 1) - (A - 1) * c - sq), (A + 1) + (A - 1) * c + sq,
                -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sq);
    }
    void highShelf(double f, double gainDb, double sr, double s = 1.0) {
        const double A = std::pow(10.0, gainDb / 40.0);
        const double w = w0(f, sr), c = std::cos(w), sn = std::sin(w);
        const double al = sn / 2 * std::sqrt((A + 1 / A) * (1 / s - 1) + 2);
        const double sq = 2 * std::sqrt(A) * al;
        setNorm(A * ((A + 1) + (A - 1) * c + sq), -2 * A * ((A - 1) + (A + 1) * c),
                A * ((A + 1) + (A - 1) * c - sq), (A + 1) - (A - 1) * c + sq,
                2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sq);
    }
    // Magnitude da resposta (para testes/calibração).
    double magnitude(double f, double sr) const {
        const std::complex<double> z = std::polar(1.0, -2.0 * kPiD * f / sr);
        const std::complex<double> num = b0 + b1 * z + b2 * z * z;
        const std::complex<double> den = 1.0 + a1 * z + a2 * z * z;
        return std::abs(num / den);
    }
};

// Filtro de variáveis de estado TPT (Zavalishin): estável sob modulação rápida.
struct SVF {
    float g = 0, k = 1, a1 = 0, a2 = 0, a3 = 0;
    float ic1 = 0, ic2 = 0;
    float lp = 0, bp = 0, hp = 0;
    void set(float fc, float q, float sr) {
        g = std::tan(kPi * std::min(fc, sr * 0.45f) / sr);
        k = 1.0f / q;
        a1 = 1.0f / (1.0f + g * (g + k));
        a2 = g * a1;
        a3 = g * a2;
    }
    inline void process(float x) {
        const float v3 = x - ic2;
        const float v1 = a1 * ic1 + a2 * v3;
        const float v2 = ic2 + a2 * ic1 + a3 * v3;
        ic1 = 2 * v1 - ic1;
        ic2 = 2 * v2 - ic2;
        lp = v2; bp = v1; hp = x - k * v1 - v2;
    }
    void reset() { ic1 = ic2 = 0; }
};

// Analog-style third-order filter discretizado por transformada bilinear.
struct ThirdOrder {
    double b[4] = {1, 0, 0, 0}, a[4] = {1, 0, 0, 0};
    double z[3] = {0, 0, 0};
    // H(s) = (B0 + B1 s + B2 s^2 + B3 s^3) / (A0 + A1 s + A2 s^2 + A3 s^3)
    void setAnalog(const double B[4], const double A[4], double sr) {
        const double c = 2.0 * sr, c2 = c * c, c3 = c2 * c;
        const double nb[4] = {
            B[0] + B[1] * c + B[2] * c2 + B[3] * c3,
            3 * B[0] + B[1] * c - B[2] * c2 - 3 * B[3] * c3,
            3 * B[0] - B[1] * c - B[2] * c2 + 3 * B[3] * c3,
            B[0] - B[1] * c + B[2] * c2 - B[3] * c3};
        const double na[4] = {
            A[0] + A[1] * c + A[2] * c2 + A[3] * c3,
            3 * A[0] + A[1] * c - A[2] * c2 - 3 * A[3] * c3,
            3 * A[0] - A[1] * c - A[2] * c2 + 3 * A[3] * c3,
            A[0] - A[1] * c + A[2] * c2 - A[3] * c3};
        for (int i = 0; i < 4; ++i) { b[i] = nb[i] / na[0]; a[i] = na[i] / na[0]; }
    }
    inline float process(float xf) {
        const double x = xf;
        const double y = b[0] * x + z[0];
        z[0] = b[1] * x - a[1] * y + z[1];
        z[1] = b[2] * x - a[2] * y + z[2];
        z[2] = b[3] * x - a[3] * y;
        return static_cast<float>(y);
    }
    void reset() { z[0] = z[1] = z[2] = 0; }
    double magnitude(double f, double sr) const {
        const std::complex<double> zi = std::polar(1.0, -2.0 * kPiD * f / sr);
        std::complex<double> num = 0, den = 0, p = 1;
        for (int i = 0; i < 4; ++i) { num += b[i] * p; den += a[i] * p; p *= zi; }
        return std::abs(num / den);
    }
};

// ----------------------------------------------------------- linhas de atraso
struct DelayLine {
    std::vector<float> buf;
    uint32_t mask = 0, w = 0;
    void prepare(int maxSamples) {
        uint32_t n = 1;
        while (n < static_cast<uint32_t>(maxSamples + 4)) n <<= 1;
        buf.assign(n, 0.f);
        mask = n - 1;
        w = 0;
    }
    void reset() { std::fill(buf.begin(), buf.end(), 0.f); }
    inline void push(float x) { buf[w] = x; w = (w + 1) & mask; }
    // atraso em amostras (>= 1), interpolação linear
    inline float read(float d) const {
        const float fi = std::floor(d);
        const int i = static_cast<int>(fi);
        const float fr = d - fi;
        const float a = buf[(w - i) & mask];
        const float b = buf[(w - i - 1) & mask];
        return a + (b - a) * fr;
    }
    inline float readInt(int d) const { return buf[(w - d) & mask]; }
};

// Valor suavizado (um polo) para evitar "zipper noise".
struct Smoothed {
    float cur = 0, target = 0, coef = 0.01f;
    void setTime(float ms, float sr) { coef = 1.0f - std::exp(-1.0f / std::max(1.0f, ms * 0.001f * sr)); }
    void snap(float v) { cur = target = v; }
    inline float next() { cur += coef * (target - cur); return cur; }
};

struct LFO {
    float phase = 0, inc = 0;
    void set(float hz, float sr) { inc = hz / sr; }
    inline float sine() {
        const float v = std::sin(2.0f * kPi * phase);
        phase += inc; if (phase >= 1.f) phase -= 1.f;
        return v;
    }
    inline float tri() {
        const float v = 4.0f * std::fabs(phase - 0.5f) - 1.0f;
        phase += inc; if (phase >= 1.f) phase -= 1.f;
        return v;
    }
};

// Seguidor de envelope de pico com ataque/liberação independentes.
struct EnvFollower {
    float env = 0, att = 0.1f, rel = 0.001f;
    void set(float attMs, float relMs, float sr) {
        att = 1.0f - std::exp(-1.0f / std::max(1.0f, attMs * 0.001f * sr));
        rel = 1.0f - std::exp(-1.0f / std::max(1.0f, relMs * 0.001f * sr));
    }
    inline float process(float x) {
        const float a = std::fabs(x);
        env += (a > env ? att : rel) * (a - env);
        return env;
    }
    void reset() { env = 0; }
};

// ------------------------------------------------------- sobreamostragem 4x
// FIR polifásico (sinc janelado Kaiser, 64 taps). Usado em todos os blocos não
// lineares para reduzir aliasing.
class Oversampler4x {
public:
    static constexpr int kFactor = 4;
    static constexpr int kTaps = 64;
    static constexpr int kPhaseTaps = kTaps / kFactor;

    Oversampler4x() { design(); reset(); }

    void reset() {
        std::memset(upHist_, 0, sizeof(upHist_));
        std::memset(dnHist_, 0, sizeof(dnHist_));
        upPos_ = dnPos_ = 0;
    }

    // Uma amostra de entrada -> 4 amostras na taxa alta.
    inline void up(float x, float* out) {
        upPos_ = (upPos_ + kPhaseTaps - 1) % kPhaseTaps;
        upHist_[upPos_] = x;
        upHist_[upPos_ + kPhaseTaps] = x;
        const float* hx = &upHist_[upPos_];
        for (int p = 0; p < kFactor; ++p) {
            const float* h = poly_[p];
            float acc = 0;
            for (int k = 0; k < kPhaseTaps; ++k) acc += h[k] * hx[k];
            out[p] = acc;
        }
    }

    // 4 amostras na taxa alta -> uma amostra de saída.
    inline float down(const float* in) {
        for (int i = 0; i < kFactor; ++i) {
            dnPos_ = (dnPos_ + kTaps - 1) % kTaps;
            dnHist_[dnPos_] = in[i];
            dnHist_[dnPos_ + kTaps] = in[i];
        }
        const float* hx = &dnHist_[dnPos_];
        float acc = 0;
        for (int k = 0; k < kTaps; ++k) acc += h_[k] * hx[k];
        return acc;
    }

    static constexpr int latency() { return (kTaps / 2) / kFactor; }  // atraso de grupo aprox. (taxa base)

private:
    static double bessel0(double x) {
        double s = 1, t = 1;
        for (int k = 1; k < 30; ++k) { t *= (x / (2 * k)) * (x / (2 * k)); s += t; }
        return s;
    }
    void design() {
        const double fc = 0.1125;  // ciclos/amostra na taxa alta (0.45 * Nyquist da taxa base)
        const double beta = 7.0;
        const double mid = (kTaps - 1) / 2.0;
        double sum = 0;
        double h[kTaps];
        for (int n = 0; n < kTaps; ++n) {
            const double t = n - mid;
            const double sinc = t == 0 ? 2 * fc : std::sin(2 * kPiD * fc * t) / (kPiD * t);
            const double r = (n - mid) / mid;
            const double w = bessel0(beta * std::sqrt(std::max(0.0, 1 - r * r))) / bessel0(beta);
            h[n] = sinc * w;
            sum += h[n];
        }
        for (int n = 0; n < kTaps; ++n) h_[n] = static_cast<float>(h[n] / sum);
        // fases do interpolador (ganho x4 para compensar zeros inseridos)
        for (int p = 0; p < kFactor; ++p)
            for (int k = 0; k < kPhaseTaps; ++k) poly_[p][k] = h_[p + kFactor * k] * kFactor;
    }

    float h_[kTaps];
    float poly_[kFactor][kPhaseTaps];
    float upHist_[kPhaseTaps * 2];
    float dnHist_[kTaps * 2];
    int upPos_ = 0, dnPos_ = 0;
};

// --------------------------------------------------------------------- FFT
class FFT {
public:
    void prepare(int n) {
        n_ = n;
        log2n_ = 0;
        while ((1 << log2n_) < n) ++log2n_;
        tw_.resize(n / 2);
        for (int i = 0; i < n / 2; ++i) tw_[i] = std::polar(1.0f, -2.0f * kPi * i / n);
        rev_.resize(n);
        for (int i = 0; i < n; ++i) {
            int r = 0;
            for (int b = 0; b < log2n_; ++b) if (i & (1 << b)) r |= 1 << (log2n_ - 1 - b);
            rev_[i] = r;
        }
    }
    int size() const { return n_; }
    // in-place; inverse sem normalização 1/N
    void transform(std::complex<float>* x, bool inverse) const {
        for (int i = 0; i < n_; ++i) if (i < rev_[i]) std::swap(x[i], x[rev_[i]]);
        for (int len = 2; len <= n_; len <<= 1) {
            const int half = len >> 1, step = n_ / len;
            for (int i = 0; i < n_; i += len) {
                for (int j = 0; j < half; ++j) {
                    std::complex<float> w = tw_[j * step];
                    if (inverse) w = std::conj(w);
                    const std::complex<float> u = x[i + j];
                    const std::complex<float> v = x[i + j + half] * w;
                    x[i + j] = u + v;
                    x[i + j + half] = u - v;
                }
            }
        }
    }
private:
    int n_ = 0, log2n_ = 0;
    std::vector<std::complex<float>> tw_;
    std::vector<int> rev_;
};

}  // namespace dsp
