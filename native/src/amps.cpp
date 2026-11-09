#include "amps.h"

#include <cmath>

namespace rig {
using namespace dsp;

// ------------------------------------------------------------------ tonestack
void Tonestack::set(const TonestackValues& v, float treble, float mid, float bass, float sr) {
    const double t = clampf(treble, 0, 1);
    const double m = clampf(mid, 0, 1);
    const double l = std::exp((clampf(bass, 0, 1) - 1.0) * 3.4);  // potenciômetro log
    const double R1 = v.R1, R2 = v.R2, R3 = v.R3, R4 = v.R4, C1 = v.C1, C2 = v.C2, C3 = v.C3;

    const double b1 = t * C1 * R1 + m * C3 * R3 + l * (C1 * R2 + C2 * R2) + (C1 * R3 + C2 * R3);
    const double b2 = t * (C1 * C2 * R1 * R4 + C1 * C3 * R1 * R4) - m * m * (C1 * C3 * R3 * R3 + C2 * C3 * R3 * R3) +
                      m * (C1 * C3 * R1 * R3 + C1 * C3 * R3 * R3 + C2 * C3 * R3 * R3) +
                      l * (C1 * C2 * R1 * R2 + C1 * C2 * R2 * R4 + C1 * C3 * R2 * R4) +
                      l * m * (C1 * C3 * R2 * R3 + C2 * C3 * R2 * R3) + (C1 * C2 * R1 * R3 + C1 * C2 * R3 * R4 + C1 * C3 * R3 * R4);
    const double b3 = l * m * (C1 * C2 * C3 * R1 * R2 * R3 + C1 * C2 * C3 * R2 * R3 * R4) -
                      m * m * (C1 * C2 * C3 * R1 * R3 * R3 + C1 * C2 * C3 * R3 * R3 * R4) +
                      m * (C1 * C2 * C3 * R1 * R3 * R3 + C1 * C2 * C3 * R3 * R3 * R4) + t * C1 * C2 * C3 * R1 * R3 * R4 -
                      t * m * C1 * C2 * C3 * R1 * R3 * R4 + t * l * C1 * C2 * C3 * R1 * R2 * R4;
    const double a1 = (C1 * R2 + C1 * R3 + C2 * R3 + C2 * R4 + C3 * R4) + m * C3 * R3 + l * (C1 * R2 + C2 * R2);
    const double a2 = m * (C1 * C3 * R1 * R3 - C2 * C3 * R3 * R4 + C1 * C3 * R3 * R3 + C2 * C3 * R3 * R3) +
                      l * m * (C1 * C3 * R2 * R3 + C2 * C3 * R2 * R3) - m * m * (C1 * C3 * R3 * R3 + C2 * C3 * R3 * R3) +
                      l * (C1 * C2 * R2 * R4 + C1 * C2 * R1 * R2 + C1 * C3 * R2 * R4 + C2 * C3 * R2 * R4) +
                      (C1 * C2 * R1 * R4 + C1 * C3 * R1 * R4 + C1 * C2 * R3 * R4 + C1 * C2 * R1 * R3 + C1 * C3 * R3 * R4 + C2 * C3 * R3 * R4);
    const double a3 = l * m * (C1 * C2 * C3 * R1 * R2 * R3 + C1 * C2 * C3 * R2 * R3 * R4) -
                      m * m * (C1 * C2 * C3 * R1 * R3 * R3 + C1 * C2 * C3 * R3 * R3 * R4) +
                      m * (C1 * C2 * C3 * R3 * R3 * R4 + C1 * C2 * C3 * R1 * R3 * R3 - C1 * C2 * C3 * R1 * R3 * R4) +
                      l * C1 * C2 * C3 * R1 * R2 * R4 + C1 * C2 * C3 * R1 * R3 * R4;
    const double B[4] = {0.0, b1, b2, b3};
    const double A[4] = {1.0, a1, a2, a3};
    f_.setAnalog(B, A, sr);
}

// -------------------------------------------------------------- modelos de amp
namespace {
constexpr TonestackValues kFender{250e3, 250e3, 10e3, 100e3, 250e-12, 100e-9, 47e-9};
constexpr TonestackValues kBassman{250e3, 1e6, 25e3, 56e3, 250e-12, 20e-9, 20e-9};
constexpr TonestackValues kMarshall{220e3, 1e6, 22e3, 33e3, 470e-12, 22e-9, 22e-9};
constexpr TonestackValues kVox{1e6, 1e6, 10e3, 100e3, 50e-12, 22e-9, 22e-9};
constexpr TonestackValues kMesa{250e3, 250e3, 25e3, 47e3, 250e-12, 100e-9, 47e-9};
constexpr TonestackValues kPeavey{250e3, 1e6, 25e3, 39e3, 250e-12, 47e-9, 22e-9};
}  // namespace

const std::vector<AmpModel>& ampModels() {
    // outTrimDb calibrado pelo teste de nível (native/test) para ~-20 dBFS RMS
    static const std::vector<AmpModel> m = {
        {"Clean Americano", "Limpo cristalino com muito headroom, inspirado nos combos americanos dos anos 60.",
         40, 0, 3, 2, -12, 14, 6, 0.05f, 12000, 20, kFender, 0, 0.2f, 2, false, 0},
        {"Tweed 59", "Limpo quente que quebra fácil ao palhetar forte. Blues e rock clássico.",
         40, 2, 1, 2, -4, 24, 10, 0.12f, 7000, 30, kBassman, 6, 0.5f, 1, false, 0},
        {"Chime Classe A", "Brilhante e com compressão de power amp. Britpop, jangle e rock dos anos 60.",
         60, -1, 4, 2, -6, 22, 10, 0.15f, 10000, 50, kVox, 8, 0.6f, 0, false, 0},
        {"Brit Plexi", "Crunch britânico clássico dos anos 60/70. Responde muito ao volume da guitarra.",
         70, -2, 3, 3, -2, 28, 12, 0.18f, 9000, 60, kMarshall, 6, 0.35f, 2, false, 0},
        {"Brit 800", "Rock e hard rock dos anos 80, mais ganho e médios agressivos.",
         90, -3, 3, 4, 4, 34, 14, 0.22f, 8000, 90, kMarshall, 4, 0.3f, 2, false, 0},
        {"Moderno Hi-Gain", "Alto ganho moderno, grave encorpado. Metal e rock pesado.",
         110, -4, 2, 5, 10, 40, 16, 0.2f, 7000, 110, kMesa, 4, 0.25f, 4, false, 0},
        {"Metal 5150", "Ganho extremo e apertado para riffs rápidos.",
         140, -5, 3, 5, 12, 44, 16, 0.25f, 7500, 140, kPeavey, 3, 0.15f, 3, false, 0},
        {"Jazz Transistor", "Transistor limpo e plano, ótimo com chorus. Jazz e funk.",
         30, 0, 2, 1, -18, 6, 0, 0.0f, 16000, 15, kFender, -6, 0.0f, 0, true, 0},
        {"Transistor Drive", "Drive de transistor de cubinho de estudo, áspero e direto.",
         80, -2, 0, 2, 0, 36, 14, 0.0f, 6000, 80, kMarshall, 0, 0.0f, 0, true, 0},
        {"Baixo Valvulado", "Amplificador de baixo valvulado, grave profundo e saturação suave.",
         25, 3, 1, 2, -8, 20, 8, 0.1f, 8000, 15, kBassman, 4, 0.4f, 3, false, 0},
    };
    return m;
}

namespace {
// Valores de calibração (dB) obtidos com native/test/calibrate.cpp.
#include "calibration.inc"
}  // namespace

AmpEffect::AmpEffect(int modelIndex) {
    const auto& all = ampModels();
    model = std::max(0, std::min(modelIndex, static_cast<int>(all.size()) - 1));
    m_ = all[model];
    if (model < static_cast<int>(sizeof(kAmpTrim) / sizeof(kAmpTrim[0]))) m_.outTrimDb = kAmpTrim[model];
    m_.stages = std::max(1, std::min(m_.stages, 6));
}

void AmpEffect::prepare(float sr, int maxBlock) {
    sr_ = sr; maxBlock_ = maxBlock;
    const float osr = sr * 4;
    inHp_.setCutoff(m_.preHp, sr);
    lowShelf_.lowShelf(200, m_.preLowDb, sr);
    bright_.highShelf(2500, m_.brightDb, sr);
    for (int s = 0; s < m_.stages; ++s) {
        stHp_[s].setCutoff(m_.stageHp, osr);
        stLp_[s].setCutoff(m_.stageLp, osr);
    }
    resonance_.lowShelf(100, m_.resonanceDb, sr);
    sagEnv_.setCutoff(6, sr);
    stageGain_ = dbToGain(m_.stageGainDb);
    dc_ = m_.solidState ? 0.f : fastTanh(m_.bias);
    preGain_.setTime(30, sr);
    powGain_.setTime(30, sr);
    outGain_.setTime(30, sr);
    update();
    preGain_.snap(preGain_.target);
    powGain_.snap(powGain_.target);
    outGain_.snap(outGain_.target);
}

void AmpEffect::reset() {
    osPre_.reset(); osPow_.reset(); inHp_.reset(); lowShelf_.reset(); bright_.reset();
    for (auto& f : stHp_) f.reset();
    for (auto& f : stLp_) f.reset();
    ts_.reset(); presence_.reset(); resonance_.reset(); sagEnv_.reset();
}

void AmpEffect::update() {
    const float g = clampf(param(0), 0, 10) / 10.f;
    preGain_.target = dbToGain(m_.gainMinDb + (m_.gainMaxDb - m_.gainMinDb) * g);
    ts_.set(m_.ts, param(3) / 10.f, param(2) / 10.f, param(1) / 10.f, sr_);
    presence_.highShelf(2500, (clampf(param(4), 0, 10) - 5.f) * 1.8f, sr_);
    const float masterDb = (clampf(param(5), 0, 10) - 5.f) * 3.2f;
    powGain_.target = dbToGain(m_.powerDb + masterDb);
    outGain_.target = dbToGain(m_.outTrimDb - 0.5f * masterDb - m_.powerDb);
}

inline float AmpEffect::stage(float x) const {
    if (m_.solidState) return hardKnee(x);
    const float v = x + m_.bias;
    const float y = v >= 0 ? fastTanh(v) : fastTanh(1.6f * v) * (1.f / 1.6f);
    return y - dc_;
}

void AmpEffect::process(float* buf, int n) {
    if (consumeDirty()) update();
    float u[4];
    const int stages = m_.stages;
    for (int i = 0; i < n; ++i) {
        float x = bright_.process(lowShelf_.process(inHp_.process(buf[i]))) * preGain_.next();
        osPre_.up(x, u);
        for (float& v : u) {
            for (int s = 0; s < stages; ++s) {
                v = stLp_[s].process(stHp_[s].process(stage(v)));
                if (s + 1 < stages) v *= stageGain_;
            }
        }
        float y = ts_.process(osPre_.down(u)) * powGain_.next();
        const float sagG = 1.f / (1.f + m_.sag * sagEnv_.z * 1.5f);
        osPow_.up(y, u);
        for (float& v : u) v = fastTanh(v * sagG);
        y = osPow_.down(u);
        sagEnv_.process(std::fabs(y));
        buf[i] = sanitize(presence_.process(resonance_.process(y)) * outGain_.next());
    }
}

// ------------------------------------------------------------------- caixas
const std::vector<CabModel>& cabModels() {
    static const std::vector<CabModel> m = {
        {"1x12 Aberta", "Combo americano de fundo aberto: grave solto e agudos brilhantes.",
         {{0, 70, 0.9f, 0}, {2, 110, 1.2f, 3}, {2, 500, 1.0f, -2}, {2, 2200, 1.5f, 4}, {2, 3800, 3.0f, -3},
          {1, 5500, 0.7f, 0}, {1, 5500, 0.7f, 0}}},
        {"2x12 Aberta", "Duas caixas de 12\" alnico, médios-agudos que brilham.",
         {{0, 80, 0.8f, 0}, {2, 120, 1.0f, 2}, {2, 800, 1.0f, -1.5f}, {2, 2600, 1.2f, 5},
          {1, 6000, 0.7f, 0}, {1, 6000, 0.7f, 0}}},
        {"4x12 Fechada V30", "Caixa fechada com falantes de médios agressivos, para drive e metal.",
         {{0, 85, 1.4f, 0}, {2, 110, 1.5f, 4}, {2, 400, 0.9f, -3}, {2, 1800, 1.0f, 3}, {2, 3200, 2.0f, 5},
          {1, 5000, 0.7f, 0}, {1, 5000, 0.7f, 0}}},
        {"4x12 Fechada Greenback", "Caixa fechada britânica clássica, médios suaves e quentes.",
         {{0, 80, 1.2f, 0}, {2, 100, 1.3f, 3}, {2, 450, 1.0f, -2}, {2, 1500, 1.0f, 3}, {2, 2500, 1.5f, 2},
          {1, 4500, 0.7f, 0}, {1, 4500, 0.7f, 0}}},
        {"2x10 Combo", "Dois falantes de 10\": ataque rápido, ótimo para limpo e blues.",
         {{0, 100, 0.8f, 0}, {2, 180, 1.0f, 2}, {2, 1200, 1.0f, 3}, {2, 3000, 1.5f, 3},
          {1, 5000, 0.7f, 0}, {1, 6500, 0.7f, 0}}},
        {"1x10 Pequena", "Cubinho de estudo: médios anasalados e pouco grave.",
         {{0, 140, 1.0f, 0}, {2, 900, 0.8f, 4}, {1, 4000, 0.7f, 0}, {1, 4000, 0.7f, 0}}},
        {"1x15 Baixo", "Caixa de 15\" para baixo, grave redondo.",
         {{0, 45, 1.0f, 0}, {2, 80, 1.0f, 3}, {2, 600, 1.0f, -2}, {1, 3500, 0.7f, 0}, {1, 3500, 0.7f, 0}}},
        {"8x10 Baixo", "Geladeira 8x10 para baixo, grave enorme e médios presentes.",
         {{0, 50, 1.2f, 0}, {2, 90, 1.0f, 2}, {2, 400, 1.0f, -2}, {2, 1500, 1.0f, 2},
          {1, 4500, 0.7f, 0}, {1, 4500, 0.7f, 0}}},
        {"IR Personalizado", "Carregue um arquivo WAV de resposta ao impulso (IR) de qualquer caixa.",
         {{0, 85, 1.4f, 0}, {2, 110, 1.5f, 4}, {2, 400, 0.9f, -3}, {2, 1800, 1.0f, 3}, {2, 3200, 2.0f, 5},
          {1, 5000, 0.7f, 0}, {1, 5000, 0.7f, 0}}},
    };
    return m;
}

int irCabModelIndex() { return static_cast<int>(cabModels().size()) - 1; }

CabEffect::CabEffect(int modelIndex) {
    model = std::max(0, std::min(modelIndex, static_cast<int>(cabModels().size()) - 1));
}

CabEffect::~CabEffect() { delete conv_.exchange(nullptr); }

void CabEffect::designModel() {
    const auto& bands = cabModels()[model].bands;
    eq_.assign(bands.size(), Biquad());
    for (size_t i = 0; i < bands.size(); ++i) {
        const auto& b = bands[i];
        if (b.type == 0) eq_[i].highpass(b.f, b.q, sr_);
        else if (b.type == 1) eq_[i].lowpass(b.f, b.q, sr_);
        else eq_[i].peak(b.f, b.q, b.db, sr_);
    }
    // Normaliza a energia da resposta ao impulso (mesmo critério das IRs carregadas).
    double e = 0;
    for (int n = 0; n < 8192; ++n) {
        float x = n == 0 ? 1.f : 0.f;
        for (auto& f : eq_) x = f.process(x);
        e += static_cast<double>(x) * x;
    }
    for (auto& f : eq_) f.reset();
    norm_ = e > 0 ? static_cast<float>(1.0 / std::sqrt(e)) : 1.f;
}

void CabEffect::prepare(float sr, int maxBlock) {
    sr_ = sr; maxBlock_ = maxBlock;
    designModel();
    level_.setTime(25, sr);
    update();
    level_.snap(level_.target);
    if (!rawIr_.empty()) delete swapConvolver(buildConvolver(rawIr_, rawSr_));
}

Convolver* CabEffect::buildConvolver(const std::vector<float>& raw, float rawSr) {
    const std::vector<float> ir = prepareCabIr(raw, rawSr, sr_, kMaxIrLen);
    if (ir.empty()) return nullptr;
    auto* c = new Convolver();
    if (!c->init(ir, 128)) { delete c; return nullptr; }
    return c;
}

void CabEffect::reset() {
    for (auto& f : eq_) f.reset();
    mic_.reset(); micLp_.reset(); lowCut_.reset(); highCut_.reset();
    if (auto* c = conv_.load()) c->reset();
}

void CabEffect::update() {
    const float mic = clampf(param(0), 0, 1);
    mic_.highShelf(2500, 2.f - mic * 8.f, sr_);
    micLp_.lowpass(14000.f * (1.f - mic * 0.55f), 0.707, sr_);
    lowCut_.highpass(clampf(param(1), 20, 300), 0.707, sr_);
    highCut_.lowpass(clampf(param(2), 2000, 16000), 0.707, sr_);
    level_.target = dbToGain(param(3) + kCabMakeupDb);
}

void CabEffect::process(float* buf, int n) {
    if (consumeDirty()) update();
    Convolver* c = conv_.load(std::memory_order_acquire);
    if (c) {
        c->process(buf, n);
        for (int i = 0; i < n; ++i)
            buf[i] = highCut_.process(lowCut_.process(buf[i])) * level_.next();
    } else {
        for (int i = 0; i < n; ++i) {
            float x = buf[i];
            for (auto& f : eq_) x = f.process(x);
            x = micLp_.process(mic_.process(x)) * norm_;
            buf[i] = highCut_.process(lowCut_.process(x)) * level_.next();
        }
    }
}

// -------------------------------------------------------------------- cubos
namespace {
struct ComboDef { const char* name; const char* desc; int amp; int cab; };
const std::vector<ComboDef>& comboDefs() {
    static const std::vector<ComboDef> c = {
        {"Cubo Transistor 1x10", "O cubinho de estudo: transistor, falante de 10\" e muita personalidade.", 8, 5},
        {"Cubo Americano 1x12", "Combo valvulado limpo de 1x12 com reverb de mola no coração.", 0, 0},
        {"Cubo Tweed 1x12", "Combo tweed dos anos 50: quente, comprimido e cheio de harmônicos.", 1, 0},
        {"Cubo Chime 2x12", "Combo classe A britânico 2x12, brilho e compressão natural.", 2, 1},
        {"Cubo Jazz 2x12", "Combo de transistor 2x12 limpo e estéreo, o favorito do jazz.", 7, 1},
        {"Cubo Brit 2x12", "Combo britânico 2x12 para crunch e rock.", 3, 1},
        {"Cubo Blues 2x10", "Combo 2x10 com breakup suave, para blues.", 1, 4},
        {"Cubo de Baixo 1x15", "Combo de baixo valvulado com falante de 15\".", 9, 6},
    };
    return c;
}
}  // namespace

ComboEffect::ComboEffect(int m)
    : amp_(comboDefs()[std::max(0, std::min(m, static_cast<int>(comboDefs().size()) - 1))].amp),
      cab_(comboDefs()[std::max(0, std::min(m, static_cast<int>(comboDefs().size()) - 1))].cab) {
    model = std::max(0, std::min(m, static_cast<int>(comboDefs().size()) - 1));
    cab_.setParam(1, 70);
    cab_.setParam(2, 10000);
    cab_.setParam(3, 0);
}

void ComboEffect::prepare(float sr, int maxBlock) {
    sr_ = sr; maxBlock_ = maxBlock;
    for (int i = 0; i < 6; ++i) amp_.setParam(i, param(i));
    cab_.setParam(0, param(6));
    amp_.prepare(sr, maxBlock);
    cab_.prepare(sr, maxBlock);
}

void ComboEffect::reset() { amp_.reset(); cab_.reset(); }

void ComboEffect::process(float* buf, int n) {
    if (consumeDirty()) {
        for (int i = 0; i < 6; ++i) amp_.setParam(i, param(i));
        cab_.setParam(0, param(6));
    }
    amp_.process(buf, n);
    cab_.process(buf, n);
}

// ------------------------------------------------------------------ registro
void registerAmps(std::vector<BlockDef>& out) {
    auto knob = [](const char* n, float d = 5.f) { return ParamDef{n, 0.f, 10.f, d, "", 0, {}}; };
    std::vector<ParamDef> ampParams = {knob("Ganho"), knob("Graves"), knob("Médios"), knob("Agudos"), knob("Presença"), knob("Master")};

    BlockDef amp{"amp", "Amplificador", "amp", "Cabeçote", "#2C2C2C",
                 "Cabeçote valvulado ou transistorizado com tonestack modelado a partir do circuito.",
                 ampParams, {}, [](int m) -> Effect* { return new AmpEffect(m); }};
    for (const auto& m : ampModels()) amp.models.push_back({m.name, m.desc});
    out.push_back(amp);

    BlockDef combo{"combo", "Cubo", "combo", "Combo", "#5A3A22",
                   "Amplificador e falante na mesma caixa, prontos para tocar.",
                   ampParams, {}, [](int m) -> Effect* { return new ComboEffect(m); }};
    combo.params.push_back({"Microfone", 0.f, 1.f, 0.3f, "%", 0, {}});
    for (const auto& c : comboDefs()) combo.models.push_back({c.name, c.desc});
    out.push_back(combo);

    BlockDef cab{"cab", "Caixa", "cab", "Caixa", "#1E1E1E",
                 "Simulação de caixa e microfone. Use \"IR Personalizado\" para carregar arquivos WAV.",
                 {{"Microfone", 0.f, 1.f, 0.3f, "%", 0, {}},
                  {"Corte graves", 20.f, 300.f, 70.f, "Hz", 0, {}},
                  {"Corte agudos", 2000.f, 16000.f, 10000.f, "Hz", 0, {}},
                  {"Nível", -24.f, 12.f, 0.f, "dB", 0, {}}},
                 {}, [](int m) -> Effect* { return new CabEffect(m); }};
    for (const auto& c : cabModels()) cab.models.push_back({c.name, c.desc});
    out.push_back(cab);
}

}  // namespace rig
