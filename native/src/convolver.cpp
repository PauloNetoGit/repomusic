#include "convolver.h"

#include <cmath>
#include <cstdio>
#include <cstring>

namespace rig {

bool Convolver::init(const std::vector<float>& ir, int blockSize) {
    if (ir.empty()) return false;
    B_ = blockSize;
    N_ = 2 * B_;
    bins_ = B_ + 1;
    len_ = static_cast<int>(ir.size());
    P_ = (len_ + B_ - 1) / B_;
    fft_.prepare(N_);

    head_.assign(B_, 0.f);
    for (int k = 0; k < B_ && k < len_; ++k) head_[k] = ir[k];
    hist_.assign(2 * B_, 0.f);
    histPos_ = 0;

    const int parts = std::max(0, P_ - 1);
    H_.assign(static_cast<size_t>(parts) * bins_, cf(0, 0));
    work_.assign(N_, cf(0, 0));
    for (int p = 1; p < P_; ++p) {
        std::fill(work_.begin(), work_.end(), cf(0, 0));
        for (int k = 0; k < B_; ++k) {
            const int idx = p * B_ + k;
            if (idx < len_) work_[k] = cf(ir[idx], 0);
        }
        fft_.transform(work_.data(), false);
        std::copy(work_.begin(), work_.begin() + bins_, H_.begin() + static_cast<size_t>(p - 1) * bins_);
    }
    fdl_.assign(static_cast<size_t>(std::max(1, parts)) * bins_, cf(0, 0));
    fdlPos_ = 0;
    acc_.assign(bins_, cf(0, 0));
    cur_.assign(B_, 0.f);
    prev_.assign(B_, 0.f);
    tail_.assign(B_, 0.f);
    pos_ = 0;
    return true;
}

void Convolver::reset() {
    std::fill(hist_.begin(), hist_.end(), 0.f);
    std::fill(fdl_.begin(), fdl_.end(), cf(0, 0));
    std::fill(cur_.begin(), cur_.end(), 0.f);
    std::fill(prev_.begin(), prev_.end(), 0.f);
    std::fill(tail_.begin(), tail_.end(), 0.f);
    pos_ = 0;
}

void Convolver::process(float* buf, int n) {
    const int parts = P_ - 1;
    for (int i = 0; i < n; ++i) {
        const float x = buf[i];
        // FIR direta para os primeiros B taps (latência zero)
        histPos_ = (histPos_ + B_ - 1) % B_;
        hist_[histPos_] = x;
        hist_[histPos_ + B_] = x;
        const float* hx = &hist_[histPos_];
        float y = 0.f;
        for (int k = 0; k < B_; ++k) y += head_[k] * hx[k];
        y += tail_[pos_];
        cur_[pos_] = x;
        buf[i] = y;

        if (++pos_ == B_) {
            pos_ = 0;
            if (parts > 0) {
                // espectro do bloco recém-completado: FFT([anterior, atual])
                for (int k = 0; k < B_; ++k) {
                    work_[k] = cf(prev_[k], 0);
                    work_[B_ + k] = cf(cur_[k], 0);
                }
                fft_.transform(work_.data(), false);
                fdlPos_ = (fdlPos_ + 1) % parts;
                std::copy(work_.begin(), work_.begin() + bins_, fdl_.begin() + static_cast<size_t>(fdlPos_) * bins_);

                // Y = soma_{p=1}^{P-1} H_p * X_{m-p}
                std::fill(acc_.begin(), acc_.end(), cf(0, 0));
                for (int p = 1; p <= parts; ++p) {
                    const int slot = (fdlPos_ - (p - 1) + parts) % parts;
                    const cf* X = &fdl_[static_cast<size_t>(slot) * bins_];
                    const cf* H = &H_[static_cast<size_t>(p - 1) * bins_];
                    for (int k = 0; k < bins_; ++k) acc_[k] += H[k] * X[k];
                }
                for (int k = 0; k < bins_; ++k) work_[k] = acc_[k];
                for (int k = bins_; k < N_; ++k) work_[k] = std::conj(acc_[N_ - k]);
                fft_.transform(work_.data(), true);
                const float inv = 1.0f / static_cast<float>(N_);
                for (int k = 0; k < B_; ++k) tail_[k] = work_[B_ + k].real() * inv;
            }
            std::swap(prev_, cur_);
        }
    }
}

// --------------------------------------------------------------------- WAV
namespace {
uint32_t rd32(const uint8_t* p) { return p[0] | (p[1] << 8) | (p[2] << 16) | (static_cast<uint32_t>(p[3]) << 24); }
uint16_t rd16(const uint8_t* p) { return static_cast<uint16_t>(p[0] | (p[1] << 8)); }
}  // namespace

bool loadWav(const std::string& path, std::vector<float>& out, float& sampleRate, std::string& err) {
    FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) { err = "Não foi possível abrir o arquivo"; return false; }
    std::vector<uint8_t> data;
    std::fseek(f, 0, SEEK_END);
    const long size = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    if (size < 44 || size > 64L * 1024 * 1024) { std::fclose(f); err = "Arquivo WAV inválido ou grande demais"; return false; }
    data.resize(static_cast<size_t>(size));
    const size_t got = std::fread(data.data(), 1, data.size(), f);
    std::fclose(f);
    if (got != data.size()) { err = "Falha ao ler o arquivo"; return false; }
    if (std::memcmp(data.data(), "RIFF", 4) != 0 || std::memcmp(data.data() + 8, "WAVE", 4) != 0) {
        err = "Não é um arquivo WAV (RIFF/WAVE)";
        return false;
    }
    int fmt = 0, channels = 0, bits = 0;
    uint32_t sr = 0;
    const uint8_t* pcm = nullptr;
    size_t pcmLen = 0;
    size_t off = 12;
    while (off + 8 <= data.size()) {
        const uint8_t* ch = data.data() + off;
        const uint32_t len = rd32(ch + 4);
        const size_t body = off + 8;
        if (body + len > data.size() && std::memcmp(ch, "data", 4) != 0) break;
        if (std::memcmp(ch, "fmt ", 4) == 0 && len >= 16) {
            fmt = rd16(ch + 8);
            channels = rd16(ch + 10);
            sr = rd32(ch + 12);
            bits = rd16(ch + 22);
            if (fmt == 0xFFFE && len >= 40) fmt = rd16(ch + 8 + 24);  // WAVE_FORMAT_EXTENSIBLE: subformato
        } else if (std::memcmp(ch, "data", 4) == 0) {
            pcm = ch + 8;
            pcmLen = std::min<size_t>(len, data.size() - body);
            break;
        }
        off = body + len + (len & 1);
    }
    if (!pcm || channels <= 0 || sr == 0) { err = "WAV sem dados ou cabeçalho inválido"; return false; }
    const int bytes = bits / 8;
    if (!((fmt == 1 && (bits == 16 || bits == 24 || bits == 32)) || (fmt == 3 && (bits == 32 || bits == 64)))) {
        err = "Formato WAV não suportado (use PCM 16/24/32 bits ou float)";
        return false;
    }
    const size_t frames = pcmLen / (static_cast<size_t>(bytes) * channels);
    out.resize(frames);
    for (size_t i = 0; i < frames; ++i) {
        const uint8_t* s = pcm + i * bytes * channels;
        float v = 0;
        if (fmt == 1) {
            if (bits == 16) v = static_cast<int16_t>(rd16(s)) / 32768.f;
            else if (bits == 24) {
                int32_t x = s[0] | (s[1] << 8) | (s[2] << 16);
                if (x & 0x800000) x |= ~0xFFFFFF;
                v = x / 8388608.f;
            } else v = static_cast<int32_t>(rd32(s)) / 2147483648.f;
        } else if (bits == 32) {
            uint32_t u = rd32(s);
            std::memcpy(&v, &u, 4);
        } else {
            uint64_t u = rd32(s) | (static_cast<uint64_t>(rd32(s + 4)) << 32);
            double d;
            std::memcpy(&d, &u, 8);
            v = static_cast<float>(d);
        }
        out[i] = std::isfinite(v) ? v : 0.f;
    }
    sampleRate = static_cast<float>(sr);
    if (out.empty()) { err = "WAV vazio"; return false; }
    return true;
}

std::vector<float> resample(const std::vector<float>& in, float fromSr, float toSr) {
    if (std::fabs(fromSr - toSr) < 0.5f) return in;
    const double ratio = static_cast<double>(fromSr) / toSr;
    const size_t outLen = static_cast<size_t>(std::floor(in.size() / ratio));
    const double fc = std::min(1.0, 1.0 / ratio);  // corte normalizado (anti-aliasing)
    const int halfW = 24;
    std::vector<float> out(outLen);
    for (size_t n = 0; n < outLen; ++n) {
        const double t = n * ratio;
        const long c = static_cast<long>(std::floor(t));
        double acc = 0;
        for (long k = c - halfW * static_cast<long>(std::ceil(ratio)); k <= c + halfW * static_cast<long>(std::ceil(ratio)); ++k) {
            if (k < 0 || k >= static_cast<long>(in.size())) continue;
            const double x = (t - k) * fc;
            const double sinc = std::fabs(x) < 1e-9 ? 1.0 : std::sin(dsp::kPiD * x) / (dsp::kPiD * x);
            const double wpos = (t - k) / (halfW * std::ceil(ratio));
            if (std::fabs(wpos) >= 1) continue;
            const double w = 0.42 + 0.5 * std::cos(dsp::kPiD * wpos) + 0.08 * std::cos(2 * dsp::kPiD * wpos);  // Blackman
            acc += in[k] * sinc * w * fc;
        }
        out[n] = static_cast<float>(acc);
    }
    return out;
}

std::vector<float> prepareCabIr(const std::vector<float>& raw, float rawSr, float targetSr, int maxLen) {
    std::vector<float> ir = resample(raw, rawSr, targetSr);
    if (ir.empty()) return ir;
    float peak = 0;
    for (float v : ir) peak = std::max(peak, std::fabs(v));
    if (peak <= 0) return {};
    // remove silêncio inicial (mantém 4 amostras antes do primeiro sinal relevante)
    size_t start = 0;
    while (start < ir.size() && std::fabs(ir[start]) < peak * 0.001f) ++start;
    start = start > 4 ? start - 4 : 0;
    ir.erase(ir.begin(), ir.begin() + static_cast<long>(start));
    if (static_cast<int>(ir.size()) > maxLen) {
        ir.resize(maxLen);
        const int fade = maxLen / 16;
        for (int i = 0; i < fade; ++i) ir[maxLen - 1 - i] *= static_cast<float>(i) / fade;
    }
    double e = 0;
    for (float v : ir) e += static_cast<double>(v) * v;
    const float g = e > 0 ? static_cast<float>(1.0 / std::sqrt(e)) : 1.f;
    for (float& v : ir) v *= g;
    return ir;
}

}  // namespace rig
