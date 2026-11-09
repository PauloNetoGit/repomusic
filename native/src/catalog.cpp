#include <cstdio>
#include <sstream>

#include "amps.h"
#include "effect.h"

namespace rig {

void registerPedals(std::vector<BlockDef>& out);

const std::vector<BlockDef>& catalog() {
    static const std::vector<BlockDef> c = [] {
        std::vector<BlockDef> v;
        registerPedals(v);
        registerAmps(v);
        return v;
    }();
    return c;
}

const BlockDef* findBlock(const std::string& id) {
    for (const auto& b : catalog())
        if (b.id == id) return &b;
    return nullptr;
}

namespace {
std::string esc(const std::string& s) {
    std::string o;
    o.reserve(s.size() + 2);
    o += '"';
    for (unsigned char ch : s) {
        switch (ch) {
            case '"': o += "\\\""; break;
            case '\\': o += "\\\\"; break;
            case '\n': o += "\\n"; break;
            case '\t': o += "\\t"; break;
            default:
                if (ch < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof(buf), "\\u%04x", ch);
                    o += buf;
                } else {
                    o += static_cast<char>(ch);
                }
        }
    }
    o += '"';
    return o;
}
std::string num(float v) {
    std::ostringstream ss;
    ss.precision(7);
    ss << v;
    return ss.str();
}
}  // namespace

std::string catalogJson() {
    std::string o = "{\"version\":1,\"irModel\":" + std::to_string(irCabModelIndex()) + ",\"blocks\":[";
    bool firstB = true;
    for (const auto& b : catalog()) {
        if (!firstB) o += ',';
        firstB = false;
        o += "{\"id\":" + esc(b.id) + ",\"name\":" + esc(b.name) + ",\"category\":" + esc(b.category) +
             ",\"group\":" + esc(b.group) + ",\"color\":" + esc(b.color) + ",\"desc\":" + esc(b.desc) + ",\"params\":[";
        for (size_t i = 0; i < b.params.size(); ++i) {
            const auto& p = b.params[i];
            if (i) o += ',';
            o += "{\"name\":" + esc(p.name) + ",\"min\":" + num(p.min) + ",\"max\":" + num(p.max) + ",\"def\":" + num(p.def) +
                 ",\"unit\":" + esc(p.unit) + ",\"steps\":" + std::to_string(p.steps) + ",\"labels\":[";
            for (size_t k = 0; k < p.labels.size(); ++k) {
                if (k) o += ',';
                o += esc(p.labels[k]);
            }
            o += "]}";
        }
        o += "],\"models\":[";
        for (size_t i = 0; i < b.models.size(); ++i) {
            if (i) o += ',';
            o += "{\"name\":" + esc(b.models[i].name) + ",\"desc\":" + esc(b.models[i].desc) + "}";
        }
        o += "]}";
    }
    o += "]}";
    return o;
}

}  // namespace rig
