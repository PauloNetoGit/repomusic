// Backend de áudio de baixa latência (AAudio no Android; stub nas demais plataformas).
#pragma once

#include <string>

namespace rig {

struct AudioStats {
    int sampleRate = 0;
    float latencyMs = 0;   // estimativa ida-e-volta
    int xruns = 0;
    int bufferFrames = 0;
    int burstFrames = 0;
    bool exclusive = false;
};

int audioStart(int inputDeviceId, int outputDeviceId, std::string& err);  // 0 = ok
void audioStop();
bool audioRunning();
AudioStats audioStats();

}  // namespace rig
