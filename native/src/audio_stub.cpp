#include "audio.h"

namespace rig {
int audioStart(int, int, std::string& err) {
    err = "Esta plataforma não tem backend de áudio em tempo real (apenas Android).";
    return -100;
}
void audioStop() {}
bool audioRunning() { return false; }
AudioStats audioStats() { return {}; }
}  // namespace rig
