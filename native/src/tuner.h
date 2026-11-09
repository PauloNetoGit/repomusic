// Afinador cromático (algoritmo YIN). A thread de áudio só escreve num anel;
// a estimativa roda na thread que chama estimate() (UI).
#pragma once

#include <atomic>
#include <cmath>
#include <vector>

namespace rig {

class Tuner {
public:
    void prepare(float sr) {
        sr_ = sr;
        ring_.assign(kRing, 0.f);
        w_.store(0);
    }
    void push(const float* x, int n) {
        uint32_t w = w_.load(std::memory_order_relaxed);
        for (int i = 0; i < n; ++i) { ring_[w & (kRing - 1)] = x[i]; ++w; }
        w_.store(w, std::memory_order_release);
    }
    // Retorna a frequência em Hz, ou 0 se não houver nota clara.
    float estimate() {
        if (ring_.empty()) return 0;
        const int D = std::max(1, static_cast<int>(std::lround(sr_ / 24000.f)));
        const float sr = sr_ / D;
        const int W = 1024;
        const int tauMax = std::min(static_cast<int>(sr / 28.f), 900);
        const int tauMin = std::max(2, static_cast<int>(sr / 1500.f));
        const int need = (W + tauMax + 2) * D;
        if (need > kRing) return 0;
        const uint32_t w = w_.load(std::memory_order_acquire);
        x_.resize(W + tauMax + 2);
        double energy = 0;
        for (size_t i = 0; i < x_.size(); ++i) {
            float acc = 0;
            for (int d = 0; d < D; ++d) acc += ring_[(w - need + i * D + d) & (kRing - 1)];
            x_[i] = acc / D;
            energy += x_[i] * x_[i];
        }
        if (std::sqrt(energy / x_.size()) < 0.0015) return 0;  // ~ -56 dBFS
        diff_.assign(tauMax + 1, 0.f);
        for (int tau = 1; tau <= tauMax; ++tau) {
            float s = 0;
            for (int j = 0; j < W; ++j) { const float d = x_[j] - x_[j + tau]; s += d * d; }
            diff_[tau] = s;
        }
        // diferença normalizada pela média cumulativa
        float run = 0;
        diff_[0] = 1;
        for (int tau = 1; tau <= tauMax; ++tau) {
            run += diff_[tau];
            diff_[tau] = run > 0 ? diff_[tau] * tau / run : 1;
        }
        int best = -1;
        for (int tau = tauMin; tau < tauMax; ++tau) {
            if (diff_[tau] < 0.15f) {
                while (tau + 1 < tauMax && diff_[tau + 1] < diff_[tau]) ++tau;
                best = tau;
                break;
            }
        }
        if (best < 0) return 0;
        float t = static_cast<float>(best);
        if (best > 1 && best < tauMax) {
            const float a = diff_[best - 1], b = diff_[best], c = diff_[best + 1];
            const float den = a - 2 * b + c;
            if (std::fabs(den) > 1e-9f) t += 0.5f * (a - c) / den;
        }
        return sr / t;
    }

private:
    static constexpr int kRing = 16384;
    float sr_ = 48000;
    std::vector<float> ring_;
    std::atomic<uint32_t> w_{0};
    std::vector<float> x_, diff_;
};

}  // namespace rig
