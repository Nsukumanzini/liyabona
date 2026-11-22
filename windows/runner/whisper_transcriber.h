#ifndef RUNNER_WHISPER_TRANSCRIBER_H_
#define RUNNER_WHISPER_TRANSCRIBER_H_

#include <cstdint>
#include <string>
#include <vector>

struct OfflineTranscription {
  bool model_available = false;
  std::string text;
  double confidence = 0.0;
};

OfflineTranscription TranscribeOfflinePcm16(
    const std::vector<uint8_t>& pcm_bytes,
    int sample_rate,
    int channels);

#endif  // RUNNER_WHISPER_TRANSCRIBER_H_
