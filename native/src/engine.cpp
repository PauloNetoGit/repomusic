#include "engine.h"

#include <chrono>
#include <cstring>
#include <thread>

#include "amps.h"
#include "dsp.h"

namespace rig {

namespace {
constexpr int kChunk = 1024;

inline float softLimit(float x) {
    const float a = std::fabs(x);
    if (a <= 0.85f) return x;
    const float y = 0.85f + 0.15f * dsp::fastTanh((a - 0.85f) / 0.15f);
    return std::copysign(y, x);
}
}  // namespace

// ===================================================================== Looper
void Looper::prepare(float sr) {
    sr_ = sr;
    buf_.assign(static_cast<size_t>(60.0f * sr), 0.f);
    len_ = pos_ = 0;
    state_ = kEmpty;
    stateOut_.store(kEmpty);
    progress_.store(0);
    lengthSec_.store(0);
}

void Looper::finishRecording() {
    if (len_ < static_cast<int>(sr_ * 0.25f)) {
        state_ = kEmpty;
        len_ = 0;
        return;
    }
    const int fade = std::min(256, len_ / 4);
    for (int i = 0; i < fade; ++i) {
        const float g = static_cast<float>(i) / fade;
        buf_[i] *= g;
        buf_[len_ - 1 - i] *= g;
    }
    state_ = kPlaying;
    pos_ = 0;
}

void Looper::process(float* b, int n) {
    if (buf_.empty()) return;
    const int c = cmd_.exchange(kNone, std::memory_order_acq_rel);
    switch (c) {
        case kMain:
            if (state_ == kEmpty) { len_ = 0; pos_ = 0; state_ = kRecording; }
            else if (state_ == kRecording) finishRecording();
            else if (state_ == kPlaying) state_ = kOverdub;
            else if (state_ == kOverdub) state_ = kPlaying;
            else if (state_ == kStopped) { state_ = kPlaying; pos_ = 0; }
            break;
        case kStop:
            if (state_ == kRecording) finishRecording();
            if (state_ != kEmpty) state_ = kStopped;
            break;
        case kClear:
            state_ = kEmpty; len_ = 0; pos_ = 0;
            break;
        case kPlay:
            if (state_ == kStopped) { state_ = kPlaying; pos_ = 0; }
            break;
        default: break;
    }
    const float lvl = level_.load(std::memory_order_relaxed);
    const int cap = static_cast<int>(buf_.size());
    for (int i = 0; i < n; ++i) {
        const float x = b[i];
        if (state_ == kRecording) {
            buf_[len_++] = x;
            if (len_ >= cap) finishRecording();
        } else if (state_ == kPlaying) {
            b[i] = x + buf_[pos_] * lvl;
            if (++pos_ >= len_) pos_ = 0;
        } else if (state_ == kOverdub) {
            const float old = buf_[pos_];
            buf_[pos_] = dsp::clampf(old + x, -4.f, 4.f);
            b[i] = x + old * lvl;
            if (++pos_ >= len_) pos_ = 0;
        }
    }
    stateOut_.store(state_, std::memory_order_relaxed);
    if (state_ == kRecording) {
        progress_.store(0, std::memory_order_relaxed);
        lengthSec_.store(len_ / sr_, std::memory_order_relaxed);
    } else {
        progress_.store(len_ > 0 ? static_cast<float>(pos_) / len_ : 0.f, std::memory_order_relaxed);
        lengthSec_.store(len_ / sr_, std::memory_order_relaxed);
    }
}

// ===================================================================== Engine
Engine& Engine::instance() {
    static Engine e;
    return e;
}

Engine::Engine() {
    chain_.store(new Chain());
    mono_.assign(kChunk, 0.f);
    dry_.assign(kChunk, 0.f);
    tuner_.prepare(sr_);
    looper_.prepare(sr_);
}

bool Engine::waitForAudioCycle() {
    if (!running_.load()) return true;
    const uint64_t c = cycles_.load(std::memory_order_acquire);
    for (int i = 0; i < 400; ++i) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
        if (cycles_.load(std::memory_order_acquire) != c) return true;
        if (!running_.load()) return true;
    }
    return false;  // áudio travado: não libera nada agora
}

void Engine::publishLocked() {
    auto* nc = new Chain();
    for (int id : order_) nc->fx.push_back(blocks_[id].get());
    Chain* old = chain_.exchange(nc, std::memory_order_acq_rel);
    if (waitForAudioCycle()) delete old;
    else chainGraveyard_.push_back(old);
}

void Engine::freeGraveyards() {
    graveyard_.clear();
    for (Chain* c : chainGraveyard_) delete c;
    chainGraveyard_.clear();
    for (Convolver* c : convGraveyard_) delete c;
    convGraveyard_.clear();
}

int Engine::addBlock(const std::string& typeId, int model, int index) {
    std::lock_guard<std::mutex> lock(mutex_);
    const BlockDef* def = findBlock(typeId);
    if (!def) return -1;
    if (def->models.empty()) model = 0;
    else model = std::max(0, std::min(model, static_cast<int>(def->models.size()) - 1));
    Effect* e = def->create(model);
    if (!e) return -2;
    e->typeId = typeId;
    e->model = model;
    e->initDefaults(*def);
    e->prepare(sr_, kChunk);
    const int id = nextId_++;
    blocks_[id].reset(e);
    if (index < 0 || index > static_cast<int>(order_.size())) index = static_cast<int>(order_.size());
    order_.insert(order_.begin() + index, id);
    publishLocked();
    return id;
}

bool Engine::removeBlock(int id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = blocks_.find(id);
    if (it == blocks_.end()) return false;
    order_.erase(std::remove(order_.begin(), order_.end(), id), order_.end());
    auto* nc = new Chain();
    for (int bid : order_) nc->fx.push_back(blocks_[bid].get());
    Chain* old = chain_.exchange(nc, std::memory_order_acq_rel);
    if (waitForAudioCycle()) {
        delete old;
        blocks_.erase(it);
    } else {
        chainGraveyard_.push_back(old);
        graveyard_.push_back(std::move(it->second));
        blocks_.erase(it);
    }
    return true;
}

bool Engine::moveBlock(int id, int newIndex) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto pos = std::find(order_.begin(), order_.end(), id);
    if (pos == order_.end()) return false;
    order_.erase(pos);
    newIndex = std::max(0, std::min(newIndex, static_cast<int>(order_.size())));
    order_.insert(order_.begin() + newIndex, id);
    publishLocked();
    return true;
}

void Engine::clearChain() {
    std::lock_guard<std::mutex> lock(mutex_);
    order_.clear();
    Chain* old = chain_.exchange(new Chain(), std::memory_order_acq_rel);
    if (waitForAudioCycle()) {
        delete old;
        blocks_.clear();
    } else {
        chainGraveyard_.push_back(old);
        for (auto& kv : blocks_) graveyard_.push_back(std::move(kv.second));
        blocks_.clear();
    }
}

int Engine::blockCount() {
    std::lock_guard<std::mutex> lock(mutex_);
    return static_cast<int>(order_.size());
}

void Engine::setParam(int id, int index, float value) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = blocks_.find(id);
    if (it != blocks_.end()) it->second->setParam(index, value);
}

void Engine::setBypass(int id, bool bypass) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = blocks_.find(id);
    if (it != blocks_.end()) it->second->bypass.store(bypass);
}

int Engine::loadIr(int id, const std::string& path, std::string& err) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = blocks_.find(id);
    if (it == blocks_.end()) { err = "Bloco não encontrado"; return -1; }
    auto* cab = dynamic_cast<CabEffect*>(it->second.get());
    if (!cab) { err = "Este bloco não aceita IR"; return -2; }
    std::vector<float> raw;
    float rawSr = 0;
    if (!loadWav(path, raw, rawSr, err)) return -3;
    Convolver* conv = cab->buildConvolver(raw, rawSr);
    if (!conv) { err = "IR vazia ou silenciosa"; return -4; }
    cab->setRawIr(raw, rawSr);
    Convolver* old = cab->swapConvolver(conv);
    if (old) {
        if (waitForAudioCycle()) delete old;
        else convGraveyard_.push_back(old);
    }
    return conv->length();
}

void Engine::clearIr(int id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = blocks_.find(id);
    if (it == blocks_.end()) return;
    auto* cab = dynamic_cast<CabEffect*>(it->second.get());
    if (!cab) return;
    cab->clearRawIr();
    Convolver* old = cab->swapConvolver(nullptr);
    if (old) {
        if (waitForAudioCycle()) delete old;
        else convGraveyard_.push_back(old);
    }
}

void Engine::configure(float sampleRate, int maxBlock) {
    std::lock_guard<std::mutex> lock(mutex_);
    // Só é chamado com o fluxo parado, então é seguro reconfigurar tudo.
    freeGraveyards();
    maxBlock_ = maxBlock;
    const bool changed = std::fabs(sampleRate - sr_) > 0.5f;
    sr_ = sampleRate;
    for (auto& kv : blocks_) {
        if (changed) kv.second->prepare(sr_, kChunk);
        kv.second->reset();
    }
    tuner_.prepare(sr_);
    if (changed) looper_.prepare(sr_);
}

void Engine::processChain(Chain* c, float* buf, int n) {
    const float step = 1.0f / (0.008f * sr_);
    for (Effect* e : c->fx) {
        const float target = e->bypass.load(std::memory_order_relaxed) ? 0.f : 1.f;
        if (e->fade == target) {
            if (target == 1.f) e->process(buf, n);
            continue;
        }
        std::memcpy(dry_.data(), buf, sizeof(float) * n);
        e->process(buf, n);
        float f = e->fade;
        for (int i = 0; i < n; ++i) {
            f = target > f ? std::min(1.f, f + step) : std::max(0.f, f - step);
            buf[i] = dry_[i] + (buf[i] - dry_[i]) * f;
        }
        e->fade = f;
    }
}

void Engine::processAudio(const float* in, float* out, int frames, int outChannels) {
    Chain* c = chain_.load(std::memory_order_acquire);
    const bool tunerOn = tunerOn_.load(std::memory_order_relaxed);
    const float muteTarget = (tunerOn && tunerMute_.load(std::memory_order_relaxed)) ? 0.f : 1.f;
    int done = 0;
    while (done < frames) {
        const int n = std::min(kChunk, frames - done);
        float* m = mono_.data();
        const float ig = inGain_.load(std::memory_order_relaxed);
        float pk = 0;
        for (int i = 0; i < n; ++i) {
            inGainCur_ += 0.002f * (ig - inGainCur_);
            const float x = in ? in[done + i] * inGainCur_ : 0.f;
            m[i] = x;
            pk = std::max(pk, std::fabs(x));
        }
        if (pk > inPeak_.load(std::memory_order_relaxed)) inPeak_.store(pk, std::memory_order_relaxed);
        if (tunerOn) tuner_.push(m, n);

        processChain(c, m, n);
        looper_.process(m, n);

        const float og = outGain_.load(std::memory_order_relaxed);
        float opk = 0;
        for (int i = 0; i < n; ++i) {
            outGainCur_ += 0.002f * (og - outGainCur_);
            muteCur_ += 0.003f * (muteTarget - muteCur_);
            const float y = softLimit(dsp::sanitize(m[i]) * outGainCur_ * muteCur_);
            opk = std::max(opk, std::fabs(y));
            float* o = out + static_cast<size_t>(done + i) * outChannels;
            for (int ch = 0; ch < outChannels; ++ch) o[ch] = y;
        }
        if (opk > outPeak_.load(std::memory_order_relaxed)) outPeak_.store(opk, std::memory_order_relaxed);
        done += n;
    }
    cycles_.fetch_add(1, std::memory_order_release);
}

void Engine::processOffline(const float* in, float* out, int frames) {
    processAudio(in, out, frames, 1);
}

}  // namespace rig
