// Interface base de todos os blocos (pedais, amplificadores, cubos, caixas).
#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <vector>

namespace rig {

struct ParamDef {
    std::string name;
    float min, max, def;
    std::string unit;
    int steps = 0;                    // 0 = contínuo; >0 = chave com N posições
    std::vector<std::string> labels;  // nomes das posições (chaves)
};

struct ModelDef {
    std::string name;
    std::string desc;
};

class Effect;

struct BlockDef {
    std::string id;        // identificador estável (salvo nos presets)
    std::string name;      // nome mostrado
    std::string category;  // pedal | amp | combo | cab
    std::string group;     // agrupamento visual no catálogo
    std::string color;     // cor do gabinete (#RRGGBB)
    std::string desc;
    std::vector<ParamDef> params;
    std::vector<ModelDef> models;  // vazio = bloco de modelo único
    std::function<Effect*(int model)> create;
};

class Effect {
public:
    static constexpr int kMaxParams = 16;

    Effect() {
        for (auto& p : params_) p.store(0.f, std::memory_order_relaxed);
    }
    virtual ~Effect() = default;

    // Chamado fora da thread de áudio (fluxo parado ou bloco ainda não publicado).
    virtual void prepare(float sampleRate, int maxBlock) = 0;
    // Thread de áudio. Processa mono in-place.
    virtual void process(float* buf, int n) = 0;
    virtual void reset() {}

    void setParam(int i, float v) {
        if (i < 0 || i >= kMaxParams) return;
        params_[i].store(v, std::memory_order_relaxed);
        dirty_.store(true, std::memory_order_release);
    }
    float param(int i) const { return params_[i].load(std::memory_order_relaxed); }

    void initDefaults(const BlockDef& def) {
        for (size_t i = 0; i < def.params.size() && i < kMaxParams; ++i) setParam(static_cast<int>(i), def.params[i].def);
    }

    std::atomic<bool> bypass{false};
    float fade = 1.0f;  // estado do crossfade de bypass (somente thread de áudio)
    int model = 0;
    std::string typeId;

protected:
    bool consumeDirty() { return dirty_.exchange(false, std::memory_order_acq_rel); }
    float sr_ = 48000.f;
    int maxBlock_ = 1024;

private:
    std::atomic<float> params_[kMaxParams];
    std::atomic<bool> dirty_{true};
};

// Registro global do catálogo (definido em catalog.cpp).
const std::vector<BlockDef>& catalog();
const BlockDef* findBlock(const std::string& id);
std::string catalogJson();

}  // namespace rig
