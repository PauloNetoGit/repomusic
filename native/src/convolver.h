// Convolução particionada com latência zero (cabeça FIR direta + cauda via FFT)
// e leitura de arquivos WAV de resposta ao impulso (IR).
#pragma once

#include <complex>
#include <string>
#include <vector>

#include "dsp.h"

namespace rig {

class Convolver {
public:
    // ir: amostras já na taxa do motor. blockSize: potência de 2.
    bool init(const std::vector<float>& ir, int blockSize = 128);
    void process(float* buf, int n);  // in-place, thread de áudio
    void reset();
    int length() const { return len_; }

private:
    using cf = std::complex<float>;
    int B_ = 128, N_ = 256, bins_ = 129, P_ = 1, len_ = 0;
    dsp::FFT fft_;
    std::vector<float> head_;      // taps [0, B)
    std::vector<float> hist_;      // histórico p/ FIR direta (buffer duplicado)
    int histPos_ = 0;
    std::vector<cf> H_;            // partições 1..P-1, bins_ cada
    std::vector<cf> fdl_;          // linha de atraso no domínio da frequência
    int fdlPos_ = 0;
    std::vector<float> cur_, prev_, tail_;
    std::vector<cf> work_, acc_;
    int pos_ = 0;
};

// Lê WAV PCM 16/24/32 bits ou float 32/64 (usa o 1º canal).
bool loadWav(const std::string& path, std::vector<float>& out, float& sampleRate, std::string& err);

// Reamostragem por sinc janelado (usada só ao carregar IR).
std::vector<float> resample(const std::vector<float>& in, float fromSr, float toSr);

// Prepara uma IR de caixa: reamostra, remove silêncio inicial, limita o tamanho
// e normaliza a energia.
std::vector<float> prepareCabIr(const std::vector<float>& raw, float rawSr, float targetSr, int maxLen);

}  // namespace rig
