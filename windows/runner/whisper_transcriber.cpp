#include "whisper_transcriber.h"

#include <windows.h>

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <mutex>
#include <system_error>
#include <string>
#include <thread>
#include <vector>

#include "whisper.h"

namespace {
constexpr wchar_t kModelRelativePath[] =
    L"speech_models\\ggml-small.en-q5_1.bin";
constexpr char kSouthAfricanEnglishPrompt[] =
    "English as spoken in South Africa. Reception at a TVET college. "
    "Names and terms may include Liyabona, TVET, Ghedzibande, NSFAS, "
    "student support, registration, Lerato, Thabo, and Amina.";

struct WhisperState {
  std::mutex mutex;
  whisper_context* context = nullptr;
  std::wstring loaded_model_path;

  ~WhisperState() {
    if (context != nullptr) whisper_free(context);
  }
};

WhisperState& State() {
  static WhisperState state;
  return state;
}

std::wstring ModelPath() {
  std::vector<wchar_t> executable(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) return L"";
  return (std::filesystem::path(std::wstring(executable.data(), length))
              .parent_path() /
          kModelRelativePath)
      .wstring();
}

std::string Trim(std::string value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  if (first == std::string::npos) return "";
  const auto last = value.find_last_not_of(" \t\r\n");
  return value.substr(first, last - first + 1);
}
}  // namespace

OfflineTranscription TranscribeOfflinePcm16(
    const std::vector<uint8_t>& pcm_bytes,
    int sample_rate,
    int channels) {
  OfflineTranscription output;
  if (pcm_bytes.size() < 8000 || sample_rate < 8000 || sample_rate > 96000 ||
      channels < 1 || channels > 2) {
    return output;
  }

  const std::wstring model_path = ModelPath();
  std::error_code path_error;
  if (model_path.empty() ||
      !std::filesystem::exists(model_path, path_error) || path_error) {
    return output;
  }
  output.model_available = true;

  auto& state = State();
  std::lock_guard<std::mutex> guard(state.mutex);
  if (state.context == nullptr || state.loaded_model_path != model_path) {
    if (state.context != nullptr) {
      whisper_free(state.context);
      state.context = nullptr;
    }
    whisper_context_params context_params = whisper_context_default_params();
    context_params.use_gpu = false;
    const std::string model_utf8 =
        std::filesystem::path(model_path).u8string();
    state.context = whisper_init_from_file_with_params(
        model_utf8.c_str(), context_params);
    if (state.context == nullptr) return output;
    state.loaded_model_path = model_path;
  }

  const size_t frame_bytes = static_cast<size_t>(channels) * 2;
  const size_t frame_count = pcm_bytes.size() / frame_bytes;
  std::vector<float> mono_samples;
  mono_samples.reserve(frame_count);
  for (size_t frame = 0; frame < frame_count; ++frame) {
    int32_t mixed = 0;
    for (int channel = 0; channel < channels; ++channel) {
      const size_t offset = frame * frame_bytes +
                            static_cast<size_t>(channel) * 2;
      const uint16_t raw = static_cast<uint16_t>(pcm_bytes[offset]) |
                           (static_cast<uint16_t>(pcm_bytes[offset + 1]) << 8);
      mixed += static_cast<int16_t>(raw);
    }
    mono_samples.push_back(static_cast<float>(mixed) /
                           (32768.0f * static_cast<float>(channels)));
  }

  std::vector<float> samples;
  const size_t target_samples = static_cast<size_t>(std::llround(
      static_cast<double>(mono_samples.size()) * 16000.0 / sample_rate));
  samples.reserve(target_samples);
  for (size_t index = 0; index < target_samples; ++index) {
    const double source_position =
        static_cast<double>(index) * sample_rate / 16000.0;
    const size_t source_index = std::min(
        static_cast<size_t>(source_position), mono_samples.size() - 1);
    const size_t next_index = std::min(source_index + 1, mono_samples.size() - 1);
    const float fraction = static_cast<float>(source_position - source_index);
    samples.push_back(mono_samples[source_index] * (1.0f - fraction) +
                      mono_samples[next_index] * fraction);
  }

  whisper_full_params params =
      whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.n_threads = static_cast<int>(std::clamp(
      std::thread::hardware_concurrency() > 1
          ? std::thread::hardware_concurrency() - 1
          : 1u,
      1u, 6u));
  params.language = "en";
  params.translate = false;
  params.no_context = true;
  params.no_timestamps = true;
  params.print_progress = false;
  params.print_realtime = false;
  params.print_timestamps = false;
  params.suppress_blank = true;
  params.initial_prompt = kSouthAfricanEnglishPrompt;
  params.temperature = 0.0f;
  params.no_speech_thold = 0.60f;
  params.logprob_thold = -1.0f;

  if (whisper_full(state.context, params, samples.data(),
                   static_cast<int>(samples.size())) != 0) {
    return output;
  }

  const int segment_count = whisper_full_n_segments(state.context);
  double token_log_probability_sum = 0.0;
  int scored_tokens = 0;
  double no_speech_probability_sum = 0.0;
  int scored_segments = 0;
  for (int index = 0; index < segment_count; ++index) {
    const char* segment = whisper_full_get_segment_text(state.context, index);
    if (segment != nullptr) {
      if (!output.text.empty()) output.text.push_back(' ');
      output.text.append(segment);
    }
    no_speech_probability_sum +=
        whisper_full_get_segment_no_speech_prob(state.context, index);
    const int token_count = whisper_full_n_tokens(state.context, index);
    for (int token = 0; token < token_count; ++token) {
      const float probability =
          whisper_full_get_token_p(state.context, index, token);
      token_log_probability_sum +=
          std::log(std::max(static_cast<double>(probability), 1e-8));
      ++scored_tokens;
    }
    ++scored_segments;
  }

  output.text = Trim(output.text);
  if (scored_segments > 0) {
    const double mean_no_speech =
        no_speech_probability_sum / static_cast<double>(scored_segments);
    output.confidence = scored_tokens > 0
        ? std::exp(token_log_probability_sum / static_cast<double>(scored_tokens))
        : 0.0;
    if (mean_no_speech > 0.70 || output.confidence < 0.05) output.text.clear();
  }
  return output;
}
