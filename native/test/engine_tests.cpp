// Testes de desktop do motor: correção numérica, estabilidade de todos os
// blocos/modelos, convolução, afinador, looper, estresse de threads e
// desempenho. Também imprime a calibração de volume dos amplificadores.
//
//   cmake -S native -B build -DPEDAL_BUILD_TESTS=ON && cmake --build build
//   ./build/engine_tests [--calibrate] [--wav-dir DIR]
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <random>
#include <string>
#include <thread>
#include <vector>

#include "../src/amps.h"
#include "../src/convolver.h"
#include "../src/effect.h"
#include "../src/engine.h"

extern "C" {
const char* ae_catalog_json();
int32_t ae_add_block(const char*, int32_t, int32_t);
void ae_clear_chain();
void ae_set_param(int32_t, int32_t, float);
void ae_set_bypass(int32_t, int32_t);
int32_t ae_process_offline(const float*, float*, int32_t, int32_t);
int32_t ae_load_ir(int32_t, const char*);
const char* ae_last_error();
int32_t ae_remove_block(int32_t);
int32_t ae_move_block(int32_t, int32_t);
}

using namespace rig;

static int g_fail = 0;
#define CHECK(cond, ...)                                  \
    do {                                                  \
        if (!(cond)) {                                    \
            std::printf("  FALHOU: " __VA_ARGS__);        \
            std::printf("  [%s:%d]\n", __FILE__, __LINE__); \
            ++g_fail;                                     \
        }                                                 \
    } while (0)

constexpr float kSr = 48000.f;

// Guitarra sintética (Karplus-Strong): notas soltas e acordes, pico ~ -10 dBFS.
std::vector<float> guitar(float seconds, float sr, unsigned seed = 1) {
    std::vector<float> out(static_cast<size_t>(seconds * sr), 0.f);
    std::mt19937 rng(seed);
    std::uniform_real_distribution<float> u(-1, 1);
    const float notes[][3] = {{82.41f, 123.47f, 164.81f}, {110.f, 164.81f, 220.f}, {146.83f, 220.f, 293.66f},
                              {196.f, 246.94f, 329.63f}, {82.41f, 0, 0}, {329.63f, 0, 0}};
    const int nEvents = static_cast<int>(seconds / 0.5f);
    for (int ev = 0; ev < nEvents; ++ev) {
        const auto& chord = notes[ev % 6];
        const size_t start = static_cast<size_t>(ev * 0.5f * sr);
        for (float f : chord) {
            if (f <= 0) continue;
            const int L = static_cast<int>(sr / f);
            std::vector<float> d(L);
            for (auto& x : d) x = u(rng);
            int idx = 0;
            for (size_t n = start; n < out.size() && n < start + static_cast<size_t>(1.2f * sr); ++n) {
                const int j = (idx + 1) % L;
                const float y = d[idx];
                d[idx] = 0.996f * 0.5f * (d[idx] + d[j]);
                idx = j;
                out[n] += y * 0.1f;
            }
        }
    }
    float pk = 0;
    for (float v : out) pk = std::max(pk, std::fabs(v));
    for (float& v : out) v *= 0.316f / pk;
    return out;
}

double rms(const std::vector<float>& x, size_t from = 0) {
    double s = 0;
    for (size_t i = from; i < x.size(); ++i) s += static_cast<double>(x[i]) * x[i];
    return std::sqrt(s / std::max<size_t>(1, x.size() - from));
}
float peak(const std::vector<float>& x) {
    float p = 0;
    for (float v : x) p = std::max(p, std::fabs(v));
    return p;
}
bool finite(const std::vector<float>& x) {
    for (float v : x) if (!std::isfinite(v)) return false;
    return true;
}
double db(double g) { return 20 * std::log10(std::max(g, 1e-12)); }

void writeWav(const std::string& path, const std::vector<float>& x, int sr, bool asFloat) {
    std::ofstream f(path, std::ios::binary);
    const int bytes = asFloat ? 4 : 2;
    const uint32_t dataLen = static_cast<uint32_t>(x.size() * bytes);
    auto w32 = [&](uint32_t v) { f.write(reinterpret_cast<const char*>(&v), 4); };
    auto w16 = [&](uint16_t v) { f.write(reinterpret_cast<const char*>(&v), 2); };
    f.write("RIFF", 4); w32(36 + dataLen); f.write("WAVE", 4);
    f.write("fmt ", 4); w32(16); w16(asFloat ? 3 : 1); w16(1); w32(sr); w32(sr * bytes); w16(bytes); w16(bytes * 8);
    f.write("data", 4); w32(dataLen);
    for (float v : x) {
        if (asFloat) f.write(reinterpret_cast<const char*>(&v), 4);
        else w16(static_cast<uint16_t>(static_cast<int16_t>(std::lround(std::max(-1.f, std::min(1.f, v)) * 32767))));
    }
}

std::vector<float> renderOffline(const std::vector<float>& in, int chunk = 192) {
    std::vector<float> out(in.size());
    for (size_t i = 0; i < in.size(); i += chunk) {
        const int n = static_cast<int>(std::min<size_t>(chunk, in.size() - i));
        ae_process_offline(in.data() + i, out.data() + i, n, static_cast<int>(kSr));
    }
    return out;
}

// ------------------------------------------------------------------------
void testTonestack() {
    std::printf("[tonestack] resposta digital vs. analógica\n");
    // Bassman, todos os knobs no meio: valores de referência do circuito (nodal).
    Tonestack ts;
    TonestackValues v{250e3, 1e6, 25e3, 56e3, 250e-12, 20e-9, 20e-9};
    ts.set(v, 0.5f, 0.5f, static_cast<float>(1.0 + std::log(0.5) / 3.4), kSr);  // l=0.5 após a curva log
    const double ref[][2] = {{300, -8.45}, {1000, -11.75}, {5000, -5.29}};
    for (auto& r : ref) {
        const double got = db(ts.magnitude(r[0], kSr));
        std::printf("  %5.0f Hz: %.2f dB (circuito %.2f)\n", r[0], got, r[1]);
        CHECK(std::fabs(got - r[1]) < 0.6, "tonestack em %.0f Hz\n", r[0]);
    }
}

void testConvolver() {
    std::printf("[convolução] particionada vs. direta\n");
    std::mt19937 rng(7);
    std::uniform_real_distribution<float> u(-1, 1);
    for (int len : {50, 128, 129, 1000, 5000, 8192}) {
        std::vector<float> h(len), x(20000);
        for (int i = 0; i < len; ++i) h[i] = u(rng) * std::exp(-i / 800.f);
        for (auto& s : x) s = u(rng);
        Convolver c;
        c.init(h, 128);
        std::vector<float> y = x;
        std::uniform_int_distribution<int> chunkD(1, 700);
        for (size_t i = 0; i < y.size();) {
            const int n = std::min<int>(chunkD(rng), static_cast<int>(y.size() - i));
            c.process(y.data() + i, n);
            i += n;
        }
        double maxErr = 0, maxRef = 0;
        for (size_t n = 0; n < x.size(); n += 37) {
            double ref = 0;
            for (int k = 0; k < len && k <= static_cast<int>(n); ++k) ref += h[k] * x[n - k];
            maxErr = std::max(maxErr, std::fabs(ref - y[n]));
            maxRef = std::max(maxRef, std::fabs(ref));
        }
        std::printf("  IR %5d taps: erro máx %.2e (relativo %.2e)\n", len, maxErr, maxErr / maxRef);
        CHECK(maxErr / maxRef < 1e-4, "convolução len=%d\n", len);
    }
}

void testOversampler() {
    std::printf("[oversampling] resposta do filtro\n");
    // Senoide de 1 kHz passa com ganho ~1; 20 kHz é atenuada pouco; imagens rejeitadas.
    for (float f : {1000.f, 10000.f, 18000.f}) {
        dsp::Oversampler4x os;
        double in = 0, out = 0;
        float u[4];
        for (int n = 0; n < 48000; ++n) {
            const float x = std::sin(2 * dsp::kPi * f * n / kSr);
            os.up(x, u);
            const float y = os.down(u);
            if (n > 1000) { in += x * x; out += y * y; }
        }
        const double g = db(std::sqrt(out / in));
        std::printf("  %5.0f Hz: %+.2f dB\n", f, g);
        if (f <= 10000) CHECK(std::fabs(g) < 0.5, "oversampler passband %.0f\n", f);
    }
}

void testTuner() {
    std::printf("[afinador] YIN\n");
    for (float f : {41.2f, 82.41f, 110.f, 146.83f, 196.f, 246.94f, 329.63f, 659.25f}) {
        Tuner t;
        t.prepare(kSr);
        std::vector<float> x(16384);
        for (size_t n = 0; n < x.size(); ++n) {
            const float ph = 2 * dsp::kPi * f * n / kSr;
            x[n] = 0.2f * (std::sin(ph) + 0.5f * std::sin(2 * ph) + 0.3f * std::sin(3 * ph));
        }
        t.push(x.data(), static_cast<int>(x.size()));
        const float est = t.estimate();
        const float cents = 1200 * std::log2(std::max(est, 1.f) / f);
        std::printf("  %7.2f Hz -> %7.2f Hz (%+.1f cents)\n", f, est, cents);
        CHECK(std::fabs(cents) < 3, "afinador %.2f\n", f);
    }
    Tuner t;
    t.prepare(kSr);
    std::vector<float> g = guitar(1.0f, kSr);
    t.push(g.data() + 12000, 8000);  // trecho de um acorde em decaimento: não pode travar nem dar NaN
    const float e = t.estimate();
    CHECK(std::isfinite(e), "afinador NaN\n");
}

void testCatalogAndAllBlocks() {
    std::printf("[catálogo] todos os blocos e modelos\n");
    const std::string json = ae_catalog_json();
    std::ofstream("build_catalog.json") << json;
    CHECK(json.size() > 1000, "catálogo curto\n");
    const std::vector<float> in = guitar(4.0f, kSr, 3);
    for (const auto& b : catalog()) {
        const int models = std::max<int>(1, static_cast<int>(b.models.size()));
        for (int m = 0; m < models; ++m) {
            ae_clear_chain();
            const int id = ae_add_block(b.id.c_str(), m, -1);
            CHECK(id > 0, "criar %s/%d\n", b.id.c_str(), m);
            // Knobs no máximo e no mínimo também não podem explodir.
            for (int pass = 0; pass < 3; ++pass) {
                for (size_t p = 0; p < b.params.size(); ++p) {
                    const auto& pd = b.params[p];
                    const float v = pass == 0 ? pd.def : pass == 1 ? pd.max : pd.min;
                    ae_set_param(id, static_cast<int>(p), v);
                }
                const std::vector<float> out = renderOffline(in);
                const bool ok = finite(out);
                CHECK(ok, "NaN/Inf em %s modelo %d passo %d\n", b.id.c_str(), m, pass);
                CHECK(peak(out) <= 1.0f, "pico > 0 dBFS em %s/%d\n", b.id.c_str(), m);
                if (pass == 0)
                    std::printf("  %-12s %-26s rms %6.1f dBFS  pico %6.1f dBFS\n", b.id.c_str(),
                                b.models.empty() ? "" : b.models[m].name.c_str(), db(rms(out)), db(peak(out)));
            }
        }
    }
    ae_clear_chain();
}

// Calibração: amplificador sozinho com knobs padrão deve dar ~-20 dBFS RMS.
void calibrate() {
    std::printf("[calibração]\n");
    const std::vector<float> in = guitar(6.0f, kSr, 5);
    const auto& models = ampModels();
    std::printf("constexpr float kAmpTrim[] = {");
    std::vector<float> trims;
    for (size_t m = 0; m < models.size(); ++m) {
        ae_clear_chain();
        ae_add_block("amp", static_cast<int>(m), -1);
        const std::vector<float> out = renderOffline(in);
        const double level = db(rms(out, 48000));
        const float current = 0;  // trims aplicados internamente; reportamos a correção relativa
        (void)current;
        trims.push_back(static_cast<float>(-20.0 - level));
    }
    for (size_t i = 0; i < trims.size(); ++i) std::printf("%s%.1ff", i ? ", " : "", trims[i]);
    std::printf("};  // somar aos valores atuais\n");
    // Caixa: mede a perda média de um amp médio através das caixas.
    double sum = 0;
    int cnt = 0;
    for (int c = 0; c < irCabModelIndex(); ++c) {
        ae_clear_chain();
        ae_add_block("amp", 3, -1);
        const std::vector<float> a = renderOffline(in);
        ae_clear_chain();
        const int id = ae_add_block("amp", 3, -1);
        (void)id;
        ae_add_block("cab", c, -1);
        const std::vector<float> b = renderOffline(in);
        const double loss = db(rms(b, 48000)) - db(rms(a, 48000));
        std::printf("  caixa %d: %+.1f dB\n", c, loss);
        sum += loss;
        ++cnt;
    }
    std::printf("constexpr float kCabMakeupDb = %.1ff;  // somar ao valor atual\n", -sum / cnt);
    ae_clear_chain();
}

void testIrLoading(const std::string& dir) {
    std::printf("[IR] leitura de WAV + reamostragem\n");
    // Gera uma IR a partir do modelo 4x12 e salva em 44.1 kHz (16 bits) e 96 kHz (float).
    CabEffect cab(2);
    cab.initDefaults(*findBlock("cab"));
    cab.prepare(kSr, 1024);
    std::vector<float> ir(4000, 0.f);
    ir[0] = 1.f;
    cab.process(ir.data(), static_cast<int>(ir.size()));
    float pk = peak(ir);
    for (float& v : ir) v *= 0.9f / pk;
    const std::vector<float> ir441 = resample(ir, kSr, 44100);
    const std::vector<float> ir96 = resample(ir, kSr, 96000);
    writeWav(dir + "/ir_44k_16bit.wav", ir441, 44100, false);
    writeWav(dir + "/ir_96k_float.wav", ir96, 96000, true);

    const std::vector<float> in = guitar(2.0f, kSr, 9);
    std::vector<double> levels;
    for (const char* name : {"ir_44k_16bit.wav", "ir_96k_float.wav"}) {
        ae_clear_chain();
        ae_add_block("amp", 3, -1);
        const int cid = ae_add_block("cab", irCabModelIndex(), -1);
        const int r = ae_load_ir(cid, (dir + "/" + name).c_str());
        std::printf("  %s -> %d amostras %s\n", name, r, r < 0 ? ae_last_error() : "");
        CHECK(r > 3000 && r < 5000, "IR %s\n", name);
        const std::vector<float> out = renderOffline(in);
        CHECK(finite(out), "IR NaN\n");
        levels.push_back(db(rms(out, 24000)));
    }
    // Mesma IR em taxas diferentes deve soar igual (mesmo nível).
    CHECK(std::fabs(levels[0] - levels[1]) < 0.5, "nível IR 44k vs 96k: %.2f vs %.2f\n", levels[0], levels[1]);
    // IR sintética equivalente ao modelo EQ: níveis próximos (mesma normalização de energia).
    ae_clear_chain();
    ae_add_block("amp", 3, -1);
    ae_add_block("cab", 2, -1);
    const double eqLevel = db(rms(renderOffline(in), 24000));
    std::printf("  nível: IR %.1f dB, caixa EQ %.1f dB\n", levels[0], eqLevel);
    CHECK(std::fabs(levels[0] - eqLevel) < 1.5, "normalização IR vs EQ\n");
    // Arquivo inválido
    std::ofstream(dir + "/bad.wav") << "nao sou um wav";
    const int bad = ae_load_ir(ae_add_block("cab", 8, -1), (dir + "/bad.wav").c_str());
    std::printf("  arquivo inválido -> %d (%s)\n", bad, ae_last_error());
    CHECK(bad < 0, "WAV inválido aceito\n");
    ae_clear_chain();
}

void testLooper() {
    std::printf("[looper]\n");
    Looper lp;
    lp.prepare(kSr);
    std::vector<float> buf(480);
    auto run = [&](int blocks, float v) {
        for (int b = 0; b < blocks; ++b) {
            std::fill(buf.begin(), buf.end(), v);
            lp.process(buf.data(), 480);
        }
    };
    lp.command(Looper::kMain);  // gravar 1 s
    run(100, 0.1f);
    CHECK(lp.state() == Looper::kRecording, "estado gravando\n");
    lp.command(Looper::kMain);  // tocar
    run(1, 0.f);
    CHECK(lp.state() == Looper::kPlaying, "estado tocando\n");
    CHECK(std::fabs(lp.lengthSec() - 1.0f) < 0.02f, "duração %.3f\n", lp.lengthSec());
    run(50, 0.f);
    CHECK(std::fabs(buf[100] - 0.1f) < 1e-5f, "reprodução %.4f\n", buf[100]);
    lp.command(Looper::kMain);  // overdub
    run(100, 0.05f);
    CHECK(lp.state() == Looper::kOverdub, "estado overdub\n");
    lp.command(Looper::kStop);
    run(1, 0.f);
    CHECK(lp.state() == Looper::kStopped, "estado parado\n");
    lp.command(Looper::kClear);
    run(1, 0.f);
    CHECK(lp.state() == Looper::kEmpty && lp.lengthSec() == 0, "limpar\n");
}

// Thread de "áudio" processando sem parar enquanto a UI mexe na cadeia.
void testThreadStress(const std::string& dir) {
    std::printf("[estresse] cadeia alterada durante o processamento\n");
    Engine& e = Engine::instance();
    e.configure(kSr, 1024);
    std::atomic<bool> stop{false};
    std::atomic<long> cycles{0};
    e.setRunning(true);
    std::thread audio([&] {
        std::vector<float> in = guitar(1.0f, kSr, 11), out(256 * 2);
        size_t pos = 0;
        while (!stop.load()) {
            if (pos + 256 > in.size()) pos = 0;
            e.processAudio(in.data() + pos, out.data(), 256, 2);
            pos += 256;
            cycles.fetch_add(1);
            std::this_thread::sleep_for(std::chrono::microseconds(200));
        }
    });
    std::mt19937 rng(3);
    const auto& cat = catalog();
    std::vector<int> ids;
    for (int it = 0; it < 400; ++it) {
        const int op = rng() % 6;
        if (op <= 1 || ids.empty()) {
            const auto& b = cat[rng() % cat.size()];
            const int m = b.models.empty() ? 0 : static_cast<int>(rng() % b.models.size());
            const int id = e.addBlock(b.id, m, static_cast<int>(rng() % (ids.size() + 1)));
            if (id > 0) ids.push_back(id);
        } else if (op == 2) {
            const size_t k = rng() % ids.size();
            e.removeBlock(ids[k]);
            ids.erase(ids.begin() + static_cast<long>(k));
        } else if (op == 3) {
            e.moveBlock(ids[rng() % ids.size()], static_cast<int>(rng() % ids.size()));
        } else if (op == 4) {
            e.setBypass(ids[rng() % ids.size()], rng() & 1);
            e.setParam(ids[rng() % ids.size()], static_cast<int>(rng() % 6), static_cast<float>(rng() % 10));
        } else {
            std::string err;
            for (int id : ids) e.loadIr(id, dir + "/ir_44k_16bit.wav", err);  // só caixas aceitam
        }
        if (it % 100 == 99) e.clearChain(), ids.clear();
    }
    stop.store(true);
    audio.join();
    e.setRunning(false);
    std::printf("  %ld ciclos de áudio sem falhas\n", cycles.load());
    CHECK(cycles.load() > 100, "poucos ciclos\n");
    e.clearChain();
}

void testPerformance(const std::string& dir) {
    std::printf("[desempenho] cadeia pesada\n");
    ae_clear_chain();
    ae_add_block("gate", 0, -1);
    ae_add_block("comp", 0, -1);
    ae_add_block("od_green", 0, -1);
    ae_add_block("amp", 5, -1);
    const int cab = ae_add_block("cab", irCabModelIndex(), -1);
    ae_load_ir(cab, (dir + "/ir_44k_16bit.wav").c_str());
    ae_add_block("chorus", 0, -1);
    ae_add_block("delay", 2, -1);
    ae_add_block("reverb", 0, -1);
    const std::vector<float> in = guitar(10.0f, kSr, 13);
    const auto t0 = std::chrono::steady_clock::now();
    const std::vector<float> out = renderOffline(in, 192);
    const double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
    std::printf("  10 s de áudio em %.3f s (%.1fx tempo real, %.1f%% de um núcleo)\n", secs, 10.0 / secs, secs * 10.0);
    CHECK(finite(out), "NaN na cadeia pesada\n");
    ae_clear_chain();
}

void renderDemos(const std::string& dir) {
    // Arquivos para ouvir no computador (opcional).
    const std::vector<float> in = guitar(6.0f, kSr, 21);
    writeWav(dir + "/demo_dry.wav", in, 48000, true);
    struct Rig { const char* name; std::vector<std::pair<const char*, int>> blocks; };
    const std::vector<Rig> rigs = {
        {"demo_clean", {{"comp", 0}, {"amp", 0}, {"cab", 0}, {"chorus", 0}, {"reverb", 1}}},
        {"demo_crunch", {{"od_green", 0}, {"amp", 3}, {"cab", 3}, {"delay", 1}}},
        {"demo_metal", {{"gate", 0}, {"amp", 6}, {"cab", 2}}},
        {"demo_combo", {{"combo", 3}, {"tremolo", 0}}},
    };
    for (const auto& r : rigs) {
        ae_clear_chain();
        for (auto& b : r.blocks) ae_add_block(b.first, b.second, -1);
        writeWav(dir + "/" + r.name + ".wav", renderOffline(in), 48000, true);
    }
    ae_clear_chain();
}

int main(int argc, char** argv) {
    std::string dir = ".";
    bool cal = false;
    for (int i = 1; i < argc; ++i) {
        if (!std::strcmp(argv[i], "--calibrate")) cal = true;
        if (!std::strcmp(argv[i], "--wav-dir") && i + 1 < argc) dir = argv[++i];
    }
    testTonestack();
    testOversampler();
    testConvolver();
    testTuner();
    testLooper();
    testCatalogAndAllBlocks();
    testIrLoading(dir);
    testThreadStress(dir);
    testPerformance(dir);
    if (cal) calibrate();
    renderDemos(dir);
    std::printf(g_fail ? "\n%d FALHA(S)\n" : "\nTODOS OS TESTES PASSARAM\n", g_fail);
    return g_fail ? 1 : 0;
}
