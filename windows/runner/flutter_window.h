#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      accessibility_channel_;
  bool accessibility_hotkey_registered_ = false;
  bool assistant_hotkey_registered_ = false;
  HWND floating_button_ = nullptr;
  std::string floating_state_ = "idle";
  std::string floating_transcript_;
  unsigned int floating_animation_phase_ = 0;

  bool CreateFloatingButton();
  void PositionFloatingButton();
  void SetFloatingState(const std::string& state,
                        const std::string& transcript);
  void ActivateAssistant();
  static LRESULT CALLBACK FloatingButtonWindowProc(
      HWND window, UINT message, WPARAM wparam, LPARAM lparam) noexcept;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
