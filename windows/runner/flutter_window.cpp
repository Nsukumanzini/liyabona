#include "flutter_window.h"

#include <optional>
#include <cwctype>
#include <set>
#include <string>
#include <variant>

#include <UIAutomation.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include <speech_to_text_windows/speech_to_text_windows.h>
#include <flutter_tts/flutter_tts_plugin.h>

namespace {
constexpr int kReadActiveAppHotkey = 0x4C;
constexpr UINT kReadActiveAppKey = 'R';
constexpr int kAssistantHotkey = 0x4D;
constexpr wchar_t kFloatingButtonClass[] = L"LiyabonaFloatingVoiceButton";
constexpr int kFloatingButtonSize = 76;
constexpr COLORREF kTransparentColor = RGB(255, 0, 255);
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

flutter::EncodableMap ReadForegroundAppText(HWND app_window) {
  HWND target = GetForegroundWindow();
  if (target == app_window) target = nullptr;
  std::wstring title;
  const std::wstring text = target == nullptr
      ? L""
      : ReadAccessibleText(target, &title);
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("title")] =
      flutter::EncodableValue(ToUtf8(title));
  payload[flutter::EncodableValue("text")] =
      flutter::EncodableValue(ToUtf8(text));
  return payload;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::CreateFloatingButton() {
  const HINSTANCE instance = GetModuleHandleW(nullptr);
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = FlutterWindow::FloatingButtonWindowProc;
  window_class.hInstance = instance;
  window_class.hCursor = LoadCursorW(nullptr, IDC_HAND);
  window_class.lpszClassName = kFloatingButtonClass;
  if (!RegisterClassExW(&window_class) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return false;
  }

  floating_button_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_LAYERED,
      kFloatingButtonClass, L"Liyabona voice assistant", WS_POPUP,
      0, 0, kFloatingButtonSize, kFloatingButtonSize, nullptr, nullptr,
      instance, this);
  if (floating_button_ == nullptr) return false;
  SetLayeredWindowAttributes(floating_button_, kTransparentColor, 0,
                             LWA_COLORKEY);
  PositionFloatingButton();
  return true;
}

void FlutterWindow::PositionFloatingButton() {
  if (floating_button_ == nullptr) return;
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  HMONITOR monitor = MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr || !GetMonitorInfoW(monitor, &monitor_info)) return;
  const int x = monitor_info.rcWork.right - kFloatingButtonSize - 18;
  const int y = monitor_info.rcWork.bottom - kFloatingButtonSize - 88;
  SetWindowPos(floating_button_, HWND_TOPMOST, x, y, kFloatingButtonSize,
               kFloatingButtonSize, SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void FlutterWindow::SetFloatingState(const std::string& state) {
  floating_state_ = state;
  if (floating_button_ != nullptr) {
    const wchar_t* label = L"Liyabona voice button. Click to speak.";
    if (state == "wake") label = L"Liyabona wake word is listening. Say Assist.";
    else if (state == "listening") label = L"Liyabona is listening.";
    else if (state == "processing") label = L"Liyabona is working.";
    else if (state == "speaking") label = L"Liyabona is speaking.";
    SetWindowTextW(floating_button_, label);
    InvalidateRect(floating_button_, nullptr, FALSE);
  }
}

void FlutterWindow::ActivateAssistant() {
  if (accessibility_channel_) {
    accessibility_channel_->InvokeMethod("activateAssistant", nullptr);
  }
}

LRESULT CALLBACK FlutterWindow::FloatingButtonWindowProc(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam) noexcept {
  FlutterWindow* owner = reinterpret_cast<FlutterWindow*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    owner = static_cast<FlutterWindow*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(owner));
  }
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_ERASEBKGND:
      return 1;
    case WM_LBUTTONUP:
      if (owner != nullptr) owner->ActivateAssistant();
      return 0;
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC dc = BeginPaint(window, &paint);
      RECT bounds{};
      GetClientRect(window, &bounds);
      HBRUSH transparent = CreateSolidBrush(kTransparentColor);
      FillRect(dc, &bounds, transparent);
      DeleteObject(transparent);

      COLORREF status_color = RGB(19, 121, 109);
      if (owner != nullptr && owner->floating_state_ == "listening") {
        status_color = RGB(176, 53, 41);
      } else if (owner != nullptr && owner->floating_state_ == "wake") {
        status_color = RGB(202, 137, 34);
      } else if (owner != nullptr && owner->floating_state_ == "processing") {
        status_color = RGB(202, 137, 34);
      } else if (owner != nullptr && owner->floating_state_ == "speaking") {
        status_color = RGB(50, 107, 177);
      }

      HBRUSH fill = CreateSolidBrush(status_color);
      HPEN border = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
      HGDIOBJ old_brush = SelectObject(dc, fill);
      HGDIOBJ old_pen = SelectObject(dc, border);
      Ellipse(dc, 7, 7, kFloatingButtonSize - 7, kFloatingButtonSize - 7);

      HPEN icon_pen = CreatePen(PS_SOLID, 4, RGB(255, 255, 255));
      HGDIOBJ previous_pen = SelectObject(dc, icon_pen);
      HBRUSH icon_brush = CreateSolidBrush(RGB(255, 255, 255));
      HGDIOBJ previous_brush = SelectObject(dc, icon_brush);
      RoundRect(dc, 31, 22, 45, 43, 7, 7);
      SelectObject(dc, GetStockObject(NULL_BRUSH));
      Arc(dc, 25, 27, 51, 52, 25, 39, 51, 39);
      MoveToEx(dc, 38, 51, nullptr);
      LineTo(dc, 38, 57);
      MoveToEx(dc, 31, 58, nullptr);
      LineTo(dc, 45, 58);

      SelectObject(dc, previous_brush);
      SelectObject(dc, previous_pen);
      DeleteObject(icon_brush);
      DeleteObject(icon_pen);
      SelectObject(dc, old_brush);
      SelectObject(dc, old_pen);
      DeleteObject(fill);
      DeleteObject(border);
      EndPaint(window, &paint);
      return 0;
    }
    case WM_NCDESTROY:
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      return DefWindowProcW(window, message, wparam, lparam);
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

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
  accessibility_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "readActiveApp") {
          result->Success(
              flutter::EncodableValue(ReadForegroundAppText(GetHandle())));
        } else if (call.method_name() == "setFloatingState") {
          const std::string* state =
              call.arguments() == nullptr
                  ? nullptr
                  : std::get_if<std::string>(call.arguments());
          if (state != nullptr) SetFloatingState(*state);
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
  accessibility_hotkey_registered_ = RegisterHotKey(
      GetHandle(), kReadActiveAppHotkey, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
      kReadActiveAppKey) != 0;
  assistant_hotkey_registered_ = RegisterHotKey(
      GetHandle(), kAssistantHotkey, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
      VK_SPACE) != 0;
  CreateFloatingButton();
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
  if (floating_button_ != nullptr) {
    DestroyWindow(floating_button_);
    floating_button_ = nullptr;
  }
  if (accessibility_hotkey_registered_) {
    UnregisterHotKey(GetHandle(), kReadActiveAppHotkey);
    accessibility_hotkey_registered_ = false;
  }
  if (assistant_hotkey_registered_) {
    UnregisterHotKey(GetHandle(), kAssistantHotkey);
    assistant_hotkey_registered_ = false;
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
    case WM_HOTKEY:
      if (wparam == kAssistantHotkey) {
        ActivateAssistant();
        return 0;
      }
      if (wparam == kReadActiveAppHotkey && accessibility_channel_) {
        accessibility_channel_->InvokeMethod(
            "activeWindowText",
            std::make_unique<flutter::EncodableValue>(
                ReadForegroundAppText(GetHandle())));
        return 0;
      }
      break;
    case WM_DISPLAYCHANGE:
      PositionFloatingButton();
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
