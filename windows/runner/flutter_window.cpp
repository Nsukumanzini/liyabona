#include "flutter_window.h"

#include <optional>
#include <cwctype>
#include <set>
#include <string>

#include <UIAutomation.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include <speech_to_text_windows/speech_to_text_windows.h>
#include <flutter_tts/flutter_tts_plugin.h>

namespace {
constexpr int kReadActiveAppHotkey = 0x4C;
constexpr UINT kReadActiveAppMessage = WM_HOTKEY;
constexpr UINT kReadActiveAppKey = 'R';
using Microsoft::WRL::ComPtr;

std::wstring BstrToString(BSTR value) {
  if (value == nullptr) return L"";
  std::wstring result(value, SysStringLen(value));
  SysFreeString(value);
  return result;
}

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return "";
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) return "";
  std::string output(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), size,
                      nullptr, nullptr);
  return output;
}

void AppendUnique(std::wstring value, std::set<std::wstring>* seen,
                  std::wstring* output, size_t limit) {
  if (value.empty() || output->size() >= limit) return;
  while (!value.empty() && iswspace(value.front())) value.erase(value.begin());
  while (!value.empty() && iswspace(value.back())) value.pop_back();
  if (value.empty() || !seen->insert(value).second) return;
  if (!output->empty()) output->append(L"\n");
  const size_t remaining = limit - output->size();
  output->append(value.substr(0, remaining));
}

std::wstring ReadAccessibleText(HWND target, std::wstring* title) {
  const int title_size = GetWindowTextLengthW(target);
  std::wstring window_title(title_size > 0 ? title_size + 1 : 1, L'\0');
  GetWindowTextW(target, window_title.data(),
                 static_cast<int>(window_title.size()));
  const size_t terminator = window_title.find(L'\0');
  if (terminator != std::wstring::npos) window_title.resize(terminator);
  *title = window_title.empty() ? L"the active app" : window_title;

  const HRESULT com_result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool uninitialize_com = SUCCEEDED(com_result);
  ComPtr<IUIAutomation> automation;
  HRESULT result = CoCreateInstance(CLSID_CUIAutomation, nullptr,
                                    CLSCTX_INPROC_SERVER,
                                    IID_PPV_ARGS(&automation));
  if (FAILED(result) || !automation) {
    if (uninitialize_com) CoUninitialize();
    return L"";
  }

  ComPtr<IUIAutomationElement> root;
  result = automation->ElementFromHandle(target, &root);
  if (FAILED(result) || !root) {
    if (uninitialize_com) CoUninitialize();
    return L"";
  }

  constexpr size_t kMaxCharacters = 8000;
  std::wstring output;
  std::set<std::wstring> seen;

  // Prefer a document range for Office documents and mail message bodies.
  IUnknown* raw_text_pattern = nullptr;
  if (SUCCEEDED(root->GetCurrentPattern(UIA_TextPatternId, &raw_text_pattern)) &&
      raw_text_pattern != nullptr) {
    ComPtr<IUIAutomationTextPattern> text_pattern;
    if (SUCCEEDED(raw_text_pattern->QueryInterface(IID_PPV_ARGS(&text_pattern))) &&
        text_pattern) {
      ComPtr<IUIAutomationTextRange> range;
      if (SUCCEEDED(text_pattern->get_DocumentRange(&range)) && range) {
        BSTR text = nullptr;
        if (SUCCEEDED(range->GetText(6000, &text))) {
          AppendUnique(BstrToString(text), &seen, &output, kMaxCharacters);
        }
      }
    }
    raw_text_pattern->Release();
  }

  ComPtr<IUIAutomationCondition> condition;
  ComPtr<IUIAutomationElementArray> elements;
  if (SUCCEEDED(automation->CreateTrueCondition(&condition)) && condition &&
      SUCCEEDED(root->FindAll(TreeScope_Descendants, condition.Get(), &elements)) &&
      elements) {
    int count = 0;
    elements->get_Length(&count);
    const int limit = count < 250 ? count : 250;
    for (int index = 0; index < limit && output.size() < kMaxCharacters; ++index) {
      ComPtr<IUIAutomationElement> element;
      if (FAILED(elements->GetElement(index, &element)) || !element) continue;

      BSTR name = nullptr;
      if (SUCCEEDED(element->get_CurrentName(&name)) && name != nullptr) {
        AppendUnique(BstrToString(name), &seen, &output, kMaxCharacters);
      }

      IUnknown* raw_value_pattern = nullptr;
      if (SUCCEEDED(element->GetCurrentPattern(UIA_ValuePatternId,
                                                &raw_value_pattern)) &&
          raw_value_pattern != nullptr) {
        ComPtr<IUIAutomationValuePattern> value_pattern;
        if (SUCCEEDED(raw_value_pattern->QueryInterface(
                IID_PPV_ARGS(&value_pattern))) && value_pattern) {
          BSTR value = nullptr;
          if (SUCCEEDED(value_pattern->get_CurrentValue(&value)) && value != nullptr) {
            AppendUnique(BstrToString(value), &seen, &output, kMaxCharacters);
          }
        }
        raw_value_pattern->Release();
      }
    }
  }

  if (uninitialize_com) CoUninitialize();
  return output;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  FlutterTtsPluginRegisterWithRegistrar(
      flutter_controller_->engine()->GetRegistrarForPlugin("FlutterTtsPlugin"));
  SpeechToTextWindowsRegisterWithRegistrar(
      flutter_controller_->engine()->GetRegistrarForPlugin(
          "SpeechToTextWindows"));
  accessibility_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "liyabona/accessibility",
      &flutter::StandardMethodCodec::GetInstance());
  accessibility_hotkey_registered_ = RegisterHotKey(
      GetHandle(), kReadActiveAppHotkey, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
      kReadActiveAppKey) != 0;
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (accessibility_hotkey_registered_) {
    UnregisterHotKey(GetHandle(), kReadActiveAppHotkey);
    accessibility_hotkey_registered_ = false;
  }
  accessibility_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case kReadActiveAppMessage:
      if (wparam == kReadActiveAppHotkey && accessibility_channel_) {
        HWND target = GetForegroundWindow();
        if (target == GetHandle()) {
          target = nullptr;
        }
        std::wstring title;
        const std::wstring text = target == nullptr
            ? L""
            : ReadAccessibleText(target, &title);
        flutter::EncodableMap payload;
        payload[flutter::EncodableValue("title")] =
            flutter::EncodableValue(ToUtf8(title));
        payload[flutter::EncodableValue("text")] =
            flutter::EncodableValue(ToUtf8(text));
        accessibility_channel_->InvokeMethod(
            "activeWindowText",
            std::make_unique<flutter::EncodableValue>(payload));
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
