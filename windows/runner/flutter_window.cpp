#include "flutter_window.h"

#include <optional>
#include <cwchar>
#include <cwctype>
#include <filesystem>
#include <exception>
#include <memory>
#include <set>
#include <string>
#include <thread>
#include <tlhelp32.h>
#include <variant>
#include <vector>

#include <shellapi.h>
#include <knownfolders.h>
#include <shlobj.h>
#include <UIAutomation.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"
#include <speech_to_text_windows/speech_to_text_windows.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include "whisper_transcriber.h"

namespace {
constexpr int kReadActiveAppHotkey = 0x4C;
constexpr UINT kReadActiveAppKey = 'R';
constexpr int kAssistantHotkey = 0x4D;
constexpr int kEmergencyStopHotkey = 0x4E;
constexpr UINT kOfflineTranscriptionReady = WM_APP + 41;
constexpr UINT kOfficeDocumentReady = WM_APP + 42;
constexpr UINT_PTR kFloatingAnimationTimer = 920;
constexpr wchar_t kFloatingButtonClass[] = L"LiyabonaFloatingVoiceButton";
constexpr int kFloatingButtonSize = 76;
constexpr int kFloatingPanelWidth = 300;
constexpr int kFloatingPanelHeight = 100;
constexpr COLORREF kTransparentColor = RGB(255, 0, 255);
using Microsoft::WRL::ComPtr;
int g_voice_access_known_state = -1;  // -1 unknown, 0 sleeping, 1 listening.
bool g_voice_access_paused_by_app = false;

bool IsVoiceAccessRunning() {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return false;
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  bool running = false;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      if (_wcsicmp(entry.szExeFile, L"VoiceAccess.exe") == 0) {
        running = true;
        break;
      }
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  return running;
}

bool StartVoiceAccessIfNeeded() {
  // Voice Access is a toggle in some Windows builds. Checking for its process
  // first avoids sending a start shortcut that could turn an active session off.
  if (IsVoiceAccessRunning()) return true;
  wchar_t system_directory[MAX_PATH]{};
  const UINT length = GetSystemDirectoryW(system_directory, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return false;
  std::wstring executable(system_directory, length);
  executable.append(L"\\VoiceAccess.exe");
  if (GetFileAttributesW(executable.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return false;
  }
  const auto launched = ShellExecuteW(nullptr, L"open", executable.c_str(),
                                      nullptr, nullptr, SW_SHOWNORMAL);
  const bool started = reinterpret_cast<INT_PTR>(launched) > 32;
  if (started) {
    // A newly opened Voice Access session starts in its listening state unless
    // Windows requires first-run setup. UIA can refine this when available.
    g_voice_access_known_state = 1;
  }
  return started;
}

struct OfflineTranscriptionResult {
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  OfflineTranscription transcription;
};

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

std::wstring ToWide(const std::string& value) {
  if (value.empty()) return L"";
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) return L"";
  std::wstring output(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), size);
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

std::wstring ControlTypeName(CONTROLTYPEID control_type) {
  switch (control_type) {
    case UIA_ButtonControlTypeId: return L"Button";
    case UIA_CheckBoxControlTypeId: return L"Checkbox";
    case UIA_ComboBoxControlTypeId: return L"Combo box";
    case UIA_EditControlTypeId: return L"Text field";
    case UIA_HyperlinkControlTypeId: return L"Link";
    case UIA_ListControlTypeId: return L"List";
    case UIA_ListItemControlTypeId: return L"List item";
    case UIA_MenuItemControlTypeId: return L"Menu item";
    case UIA_RadioButtonControlTypeId: return L"Radio button";
    case UIA_TabControlTypeId: return L"Tab list";
    case UIA_TabItemControlTypeId: return L"Tab";
    case UIA_TextControlTypeId: return L"Text";
    case UIA_TreeItemControlTypeId: return L"Tree item";
    default: return L"Control";
  }
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

  constexpr size_t kMaxCharacters = 32000;
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
        if (SUCCEEDED(range->GetText(24000, &text))) {
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

      int control_type = UIA_CustomControlTypeId;
      element->get_CurrentControlType(&control_type);
      const std::wstring role = ControlTypeName(control_type);
      BSTR name = nullptr;
      std::wstring label;
      if (SUCCEEDED(element->get_CurrentName(&name)) && name != nullptr) {
        label = BstrToString(name);
      }

      VARIANT password_property;
      VariantInit(&password_property);
      const bool is_password =
          SUCCEEDED(element->GetCurrentPropertyValue(
              UIA_IsPasswordPropertyId, &password_property)) &&
          password_property.vt == VT_BOOL &&
          password_property.boolVal == VARIANT_TRUE;
      VariantClear(&password_property);

      std::wstring accessible_line;
      if (!label.empty()) {
        accessible_line = role + L": " + label;
      }

      IUnknown* raw_value_pattern = nullptr;
      if (!is_password && SUCCEEDED(element->GetCurrentPattern(UIA_ValuePatternId,
                                                &raw_value_pattern)) &&
          raw_value_pattern != nullptr) {
        ComPtr<IUIAutomationValuePattern> value_pattern;
        if (SUCCEEDED(raw_value_pattern->QueryInterface(
                IID_PPV_ARGS(&value_pattern))) && value_pattern) {
          BSTR value = nullptr;
          if (SUCCEEDED(value_pattern->get_CurrentValue(&value)) && value != nullptr) {
            const std::wstring value_text = BstrToString(value);
            if (!value_text.empty()) {
              if (!accessible_line.empty()) accessible_line.append(L", ");
              accessible_line.append(L"value: ");
              accessible_line.append(value_text);
            }
          }
        }
        raw_value_pattern->Release();
      }
      AppendUnique(accessible_line, &seen, &output, kMaxCharacters);
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

struct OfficeOperationResult {
  bool success = false;
  std::wstring path;
  std::wstring error;
};

struct OfficeDocumentResponse {
  std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  OfficeOperationResult operation;
};

HRESULT DispatchId(IDispatch* target, const wchar_t* name, DISPID* id) {
  if (target == nullptr || name == nullptr || id == nullptr) return E_POINTER;
  LPOLESTR member = const_cast<LPOLESTR>(name);
  return target->GetIDsOfNames(IID_NULL, &member, 1, LOCALE_USER_DEFAULT, id);
}

HRESULT DispatchInvoke(IDispatch* target, const wchar_t* name, WORD flags,
                       VARIANT* arguments, UINT argument_count,
                       VARIANT* returned = nullptr) {
  DISPID id = DISPID_UNKNOWN;
  HRESULT status = DispatchId(target, name, &id);
  if (FAILED(status)) return status;
  DISPPARAMS parameters{};
  parameters.rgvarg = arguments;
  parameters.cArgs = argument_count;
  VARIANT ignored;
  VariantInit(&ignored);
  VARIANT* output = returned == nullptr ? &ignored : returned;
  status = target->Invoke(id, IID_NULL, LOCALE_USER_DEFAULT, flags,
                         &parameters, output, nullptr, nullptr);
  VariantClear(&ignored);
  return status;
}

ComPtr<IDispatch> DispatchObjectProperty(IDispatch* target,
                                         const wchar_t* property) {
  ComPtr<IDispatch> object;
  VARIANT returned;
  VariantInit(&returned);
  if (SUCCEEDED(DispatchInvoke(target, property, DISPATCH_PROPERTYGET, nullptr,
                               0, &returned))) {
    if (returned.vt == VT_DISPATCH && returned.pdispVal != nullptr) {
      object.Attach(returned.pdispVal);
      returned.vt = VT_EMPTY;
    } else if (returned.vt == VT_UNKNOWN && returned.punkVal != nullptr) {
      returned.punkVal->QueryInterface(IID_PPV_ARGS(&object));
    }
  }
  VariantClear(&returned);
  return object;
}

bool DispatchPutString(IDispatch* target, const wchar_t* property,
                       const std::wstring& value) {
  DISPID id = DISPID_UNKNOWN;
  if (FAILED(DispatchId(target, property, &id))) return false;
  VARIANT argument;
  VariantInit(&argument);
  argument.vt = VT_BSTR;
  argument.bstrVal = SysAllocStringLen(value.data(),
                                       static_cast<UINT>(value.size()));
  if (argument.bstrVal == nullptr) return false;
  DISPID named = DISPID_PROPERTYPUT;
  DISPPARAMS parameters{&argument, &named, 1, 1};
  const HRESULT status = target->Invoke(id, IID_NULL, LOCALE_USER_DEFAULT,
                                        DISPATCH_PROPERTYPUT, &parameters,
                                        nullptr, nullptr, nullptr);
  VariantClear(&argument);
  return SUCCEEDED(status);
}

bool DispatchPutBool(IDispatch* target, const wchar_t* property, bool value) {
  DISPID id = DISPID_UNKNOWN;
  if (FAILED(DispatchId(target, property, &id))) return false;
  VARIANT argument;
  VariantInit(&argument);
  argument.vt = VT_BOOL;
  argument.boolVal = value ? VARIANT_TRUE : VARIANT_FALSE;
  DISPID named = DISPID_PROPERTYPUT;
  DISPPARAMS parameters{&argument, &named, 1, 1};
  return SUCCEEDED(target->Invoke(id, IID_NULL, LOCALE_USER_DEFAULT,
                                  DISPATCH_PROPERTYPUT, &parameters, nullptr,
                                  nullptr, nullptr));
}

bool DispatchPutLong(IDispatch* target, const wchar_t* property, LONG value) {
  DISPID id = DISPID_UNKNOWN;
  if (FAILED(DispatchId(target, property, &id))) return false;
  VARIANT argument;
  VariantInit(&argument);
  argument.vt = VT_I4;
  argument.lVal = value;
  DISPID named = DISPID_PROPERTYPUT;
  DISPPARAMS parameters{&argument, &named, 1, 1};
  return SUCCEEDED(target->Invoke(id, IID_NULL, LOCALE_USER_DEFAULT,
                                  DISPATCH_PROPERTYPUT, &parameters, nullptr,
                                  nullptr, nullptr));
}

std::wstring SafeOfficeTitle(const std::wstring& title) {
  std::wstring safe;
  for (const wchar_t character : title) {
    if (iswalnum(character) || character == L' ' || character == L'-' ||
        character == L'_') {
      safe.push_back(character);
    }
  }
  while (!safe.empty() && iswspace(safe.back())) safe.pop_back();
  while (!safe.empty() && iswspace(safe.front())) safe.erase(safe.begin());
  if (safe.empty()) safe = L"Reception Draft";
  if (safe.size() > 80) safe.resize(80);
  return safe;
}

std::wstring NewOfficePath(const std::wstring& title,
                           const wchar_t* extension) {
  PWSTR local_app_data = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE,
                                 nullptr, &local_app_data))) {
    return L"";
  }
  std::filesystem::path directory(local_app_data);
  CoTaskMemFree(local_app_data);
  directory /= L"Liyabona";
  directory /= L"Documents";
  std::error_code error;
  std::filesystem::create_directories(directory, error);
  if (error) return L"";
  const std::wstring safe_title = SafeOfficeTitle(title);
  for (int index = 1; index < 10000; ++index) {
    std::wstring name = safe_title;
    if (index > 1) name.append(L" (" + std::to_wstring(index) + L")");
    name.append(extension);
    const std::filesystem::path candidate = directory / name;
    if (!std::filesystem::exists(candidate, error) && !error) {
      return candidate.wstring();
    }
  }
  return L"";
}

bool PutTextRange(IDispatch* range, const std::wstring& text) {
  return DispatchPutString(range, L"Text", text);
}

OfficeOperationResult CreateWordDocument(const std::wstring& title,
                                         const std::wstring& body) {
  OfficeOperationResult result;
  result.path = NewOfficePath(title, L".docx");
  if (result.path.empty()) {
    result.error = L"The Liyabona Documents folder is unavailable.";
    return result;
  }
  const HRESULT com_status = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool uninitialize = SUCCEEDED(com_status);
  CLSID class_id{};
  ComPtr<IDispatch> word;
  HRESULT status = CLSIDFromProgID(L"Word.Application", &class_id);
  if (SUCCEEDED(status)) {
    status = CoCreateInstance(class_id, nullptr, CLSCTX_LOCAL_SERVER,
                              IID_PPV_ARGS(&word));
  }
  if (FAILED(status) || !word) {
    result.error = L"Microsoft Word is not installed or could not be started.";
  } else {
    DispatchPutBool(word.Get(), L"Visible", true);
    ComPtr<IDispatch> documents = DispatchObjectProperty(word.Get(), L"Documents");
    VARIANT created;
    VariantInit(&created);
    status = documents ? DispatchInvoke(documents.Get(), L"Add", DISPATCH_METHOD,
                                        nullptr, 0, &created) : E_FAIL;
    ComPtr<IDispatch> document;
    if (SUCCEEDED(status) && created.vt == VT_DISPATCH && created.pdispVal) {
      document.Attach(created.pdispVal);
      created.vt = VT_EMPTY;
    }
    VariantClear(&created);
    ComPtr<IDispatch> range = DispatchObjectProperty(document.Get(), L"Content");
    VARIANT save_arguments[2];
    VariantInit(&save_arguments[0]);
    VariantInit(&save_arguments[1]);
    save_arguments[0].vt = VT_I4;
    save_arguments[0].lVal = 16;  // wdFormatXMLDocument (.docx)
    save_arguments[1].vt = VT_BSTR;
    save_arguments[1].bstrVal = SysAllocString(result.path.c_str());
    const std::wstring complete_document = title + L"\r\n\r\n" + body;
    const bool written = range && PutTextRange(range.Get(), complete_document);
    const bool saved = written && save_arguments[1].bstrVal != nullptr &&
        SUCCEEDED(DispatchInvoke(document.Get(), L"SaveAs2", DISPATCH_METHOD,
                                 save_arguments, 2));
    VariantClear(&save_arguments[0]);
    VariantClear(&save_arguments[1]);
    std::error_code file_error;
    if (saved && std::filesystem::exists(result.path, file_error) &&
        !file_error) {
      result.success = true;
    } else {
      result.error = L"Word could not write the new document.";
      result.path.clear();
    }
  }
  word.Reset();
  if (uninitialize) CoUninitialize();
  return result;
}

bool AddPowerPointTextBox(IDispatch* shapes, LONG left, LONG top, LONG width,
                          LONG height, const std::wstring& text) {
  // AddTextbox arguments are passed in reverse COM order.
  VARIANT arguments[5];
  for (auto& argument : arguments) VariantInit(&argument);
  arguments[0].vt = VT_I4; arguments[0].lVal = height;
  arguments[1].vt = VT_I4; arguments[1].lVal = width;
  arguments[2].vt = VT_I4; arguments[2].lVal = top;
  arguments[3].vt = VT_I4; arguments[3].lVal = left;
  arguments[4].vt = VT_I4; arguments[4].lVal = 1;  // horizontal text
  VARIANT returned;
  VariantInit(&returned);
  const HRESULT status = DispatchInvoke(shapes, L"AddTextbox", DISPATCH_METHOD,
                                        arguments, 5, &returned);
  for (auto& argument : arguments) VariantClear(&argument);
  ComPtr<IDispatch> shape;
  if (SUCCEEDED(status) && returned.vt == VT_DISPATCH && returned.pdispVal) {
    shape.Attach(returned.pdispVal);
    returned.vt = VT_EMPTY;
  }
  VariantClear(&returned);
  ComPtr<IDispatch> frame = DispatchObjectProperty(shape.Get(), L"TextFrame");
  ComPtr<IDispatch> range = DispatchObjectProperty(frame.Get(), L"TextRange");
  return range && PutTextRange(range.Get(), text);
}

OfficeOperationResult CreatePowerPoint(const std::wstring& title,
                                       const std::wstring& body) {
  OfficeOperationResult result;
  result.path = NewOfficePath(title, L".pptx");
  if (result.path.empty()) {
    result.error = L"The Liyabona Documents folder is unavailable.";
    return result;
  }
  const HRESULT com_status = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const bool uninitialize = SUCCEEDED(com_status);
  CLSID class_id{};
  ComPtr<IDispatch> powerpoint;
  HRESULT status = CLSIDFromProgID(L"PowerPoint.Application", &class_id);
  if (SUCCEEDED(status)) {
    status = CoCreateInstance(class_id, nullptr, CLSCTX_LOCAL_SERVER,
                              IID_PPV_ARGS(&powerpoint));
  }
  if (FAILED(status) || !powerpoint) {
    result.error = L"Microsoft PowerPoint is not installed or could not be started.";
  } else {
    DispatchPutLong(powerpoint.Get(), L"Visible", -1);
    ComPtr<IDispatch> presentations =
        DispatchObjectProperty(powerpoint.Get(), L"Presentations");
    VARIANT created;
    VariantInit(&created);
    status = presentations ? DispatchInvoke(presentations.Get(), L"Add",
                                             DISPATCH_METHOD, nullptr, 0,
                                             &created) : E_FAIL;
    ComPtr<IDispatch> presentation;
    if (SUCCEEDED(status) && created.vt == VT_DISPATCH && created.pdispVal) {
      presentation.Attach(created.pdispVal);
      created.vt = VT_EMPTY;
    }
    VariantClear(&created);
    ComPtr<IDispatch> slides =
        DispatchObjectProperty(presentation.Get(), L"Slides");
    VARIANT add_arguments[2];
    VariantInit(&add_arguments[0]);
    VariantInit(&add_arguments[1]);
    add_arguments[0].vt = VT_I4; add_arguments[0].lVal = 12;  // blank layout
    add_arguments[1].vt = VT_I4; add_arguments[1].lVal = 1;
    VARIANT slide_value;
    VariantInit(&slide_value);
    status = slides ? DispatchInvoke(slides.Get(), L"Add", DISPATCH_METHOD,
                                     add_arguments, 2, &slide_value) : E_FAIL;
    VariantClear(&add_arguments[0]);
    VariantClear(&add_arguments[1]);
    ComPtr<IDispatch> slide;
    if (SUCCEEDED(status) && slide_value.vt == VT_DISPATCH && slide_value.pdispVal) {
      slide.Attach(slide_value.pdispVal);
      slide_value.vt = VT_EMPTY;
    }
    VariantClear(&slide_value);
    ComPtr<IDispatch> shapes = DispatchObjectProperty(slide.Get(), L"Shapes");
    const bool content_added = shapes &&
        AddPowerPointTextBox(shapes.Get(), 45, 25, 630, 75, title) &&
        AddPowerPointTextBox(shapes.Get(), 55, 120, 620, 360, body);
    VARIANT save_arguments[2];
    VariantInit(&save_arguments[0]);
    VariantInit(&save_arguments[1]);
    save_arguments[0].vt = VT_I4; save_arguments[0].lVal = 24;  // .pptx
    save_arguments[1].vt = VT_BSTR;
    save_arguments[1].bstrVal = SysAllocString(result.path.c_str());
    const bool saved = content_added && save_arguments[1].bstrVal != nullptr &&
        SUCCEEDED(DispatchInvoke(presentation.Get(), L"SaveAs", DISPATCH_METHOD,
                                 save_arguments, 2));
    VariantClear(&save_arguments[0]);
    VariantClear(&save_arguments[1]);
    std::error_code file_error;
    if (saved && std::filesystem::exists(result.path, file_error) &&
        !file_error) {
      result.success = true;
    } else {
      result.error = L"PowerPoint could not write the new presentation.";
      result.path.clear();
    }
  }
  powerpoint.Reset();
  if (uninitialize) CoUninitialize();
  return result;
}

bool SendVoiceAccessSleepShortcut() {
  INPUT inputs[6]{};
  const WORD keys[] = {VK_MENU, VK_SHIFT, 'B', 'B', VK_SHIFT, VK_MENU};
  for (size_t i = 0; i < 6; ++i) {
    inputs[i].type = INPUT_KEYBOARD;
    inputs[i].ki.wVk = keys[i];
    if (i >= 3) inputs[i].ki.dwFlags = KEYEVENTF_KEYUP;
  }
  return SendInput(6, inputs, sizeof(INPUT)) == 6;
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
  const bool expanded = floating_state_ != "idle";
  const int width = expanded ? kFloatingPanelWidth : kFloatingButtonSize;
  const int height = expanded ? kFloatingPanelHeight : kFloatingButtonSize;
  const int x = monitor_info.rcWork.right - width - 18;
  const int y = monitor_info.rcWork.bottom - height - 22;
  SetWindowPos(floating_button_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void FlutterWindow::SetFloatingState(const std::string& state,
                                     const std::string& transcript) {
  const bool changed_state = floating_state_ != state;
  floating_state_ = state;
  floating_transcript_ = transcript.substr(0, 280);
  if (floating_button_ != nullptr) {
    std::wstring label = L"Liyabona assistant. Click to start voice help.";
    if (state == "wake") label = L"Liyabona is listening locally for Assist.";
    else if (state == "listening") label = L"Liyabona is listening. Click to stop.";
    else if (state == "processing") label = L"Liyabona is understanding your request.";
    else if (state == "speaking") label = L"Liyabona is speaking. Click to stop.";
    SetWindowTextW(floating_button_, label.c_str());
    if (state == "idle") {
      KillTimer(floating_button_, kFloatingAnimationTimer);
      floating_animation_phase_ = 0;
    } else if (changed_state || state != "idle") {
      SetTimer(floating_button_, kFloatingAnimationTimer, 90, nullptr);
    }
    PositionFloatingButton();
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

      const bool expanded = owner != nullptr && owner->floating_state_ != "idle";
      if (expanded) {
        HBRUSH panel = CreateSolidBrush(RGB(23, 76, 66));
        HPEN panel_border = CreatePen(PS_SOLID, 1, RGB(35, 116, 100));
        HGDIOBJ old_panel_brush = SelectObject(dc, panel);
        HGDIOBJ old_panel_pen = SelectObject(dc, panel_border);
        RoundRect(dc, 1, 1, bounds.right - 1, bounds.bottom - 1, 26, 26);
        SelectObject(dc, old_panel_brush);
        SelectObject(dc, old_panel_pen);
        DeleteObject(panel);
        DeleteObject(panel_border);
      } else {
        HBRUSH transparent = CreateSolidBrush(kTransparentColor);
        FillRect(dc, &bounds, transparent);
        DeleteObject(transparent);
      }

      const int center_x = expanded ? 40 : kFloatingButtonSize / 2;
      const int center_y = expanded ? bounds.bottom / 2 : kFloatingButtonSize / 2;
      if (expanded && owner != nullptr) {
        const int wave = 1 + static_cast<int>(
            (owner->floating_animation_phase_ <= 12
                 ? owner->floating_animation_phase_
                 : 24 - owner->floating_animation_phase_) /
            4);
        HPEN halo = CreatePen(PS_SOLID, 2, status_color);
        HGDIOBJ previous_halo = SelectObject(dc, halo);
        SelectObject(dc, GetStockObject(NULL_BRUSH));
        Ellipse(dc, center_x - 27 - wave, center_y - 27 - wave,
                center_x + 27 + wave, center_y + 27 + wave);
        SelectObject(dc, previous_halo);
        DeleteObject(halo);
      }

      HBRUSH fill = CreateSolidBrush(status_color);
      HPEN border = CreatePen(PS_SOLID, 1, RGB(255, 255, 255));
      HGDIOBJ old_brush = SelectObject(dc, fill);
      HGDIOBJ old_pen = SelectObject(dc, border);
      const int face_radius = expanded ? 24 : 30;
      Ellipse(dc, center_x - face_radius, center_y - face_radius,
              center_x + face_radius, center_y + face_radius);

      HPEN icon_pen = CreatePen(PS_SOLID, 3, RGB(255, 255, 255));
      HGDIOBJ previous_pen = SelectObject(dc, icon_pen);
      HBRUSH icon_brush = CreateSolidBrush(expanded ? RGB(23, 76, 66)
                                                    : RGB(255, 255, 255));
      HGDIOBJ previous_brush = SelectObject(dc, icon_brush);
      if (expanded) {
        // A simple Liyabona face gives the always-on-top control a friendly
        // identity; the ring animation communicates listening and speaking.
        Ellipse(dc, center_x - 11, center_y - 8, center_x - 4, center_y - 1);
        Ellipse(dc, center_x + 4, center_y - 8, center_x + 11, center_y - 1);
        SelectObject(dc, GetStockObject(NULL_BRUSH));
        Arc(dc, center_x - 12, center_y - 5, center_x + 12, center_y + 13,
            center_x - 12, center_y + 4, center_x + 12, center_y + 4);
      } else {
        RoundRect(dc, center_x - 7, center_y - 16, center_x + 7,
                  center_y + 5, 7, 7);
        SelectObject(dc, GetStockObject(NULL_BRUSH));
        Arc(dc, center_x - 13, center_y - 11, center_x + 13, center_y + 14,
            center_x - 13, center_y + 1, center_x + 13, center_y + 1);
        MoveToEx(dc, center_x, center_y + 14, nullptr);
        LineTo(dc, center_x, center_y + 20);
        MoveToEx(dc, center_x - 7, center_y + 21, nullptr);
        LineTo(dc, center_x + 7, center_y + 21);
      }

      SelectObject(dc, previous_brush);
      SelectObject(dc, previous_pen);
      DeleteObject(icon_brush);
      DeleteObject(icon_pen);
      SelectObject(dc, old_brush);
      SelectObject(dc, old_pen);
      DeleteObject(fill);
      DeleteObject(border);

      if (expanded && owner != nullptr) {
        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, RGB(255, 255, 255));
        HFONT title_font = CreateFontW(-15, 0, 0, 0, FW_BOLD, FALSE, FALSE,
                                       FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                       CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                       DEFAULT_PITCH | FF_SWISS, L"Segoe UI");
        HGDIOBJ old_font = SelectObject(dc, title_font);
        RECT title_rect{76, 9, bounds.right - 12, 30};
        DrawTextW(dc, L"Liyabona AI", -1, &title_rect,
                  DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        const wchar_t* status = L"Ready";
        if (owner->floating_state_ == "wake") status = L"Listening for Assist";
        else if (owner->floating_state_ == "listening") status = L"Listening - click to stop";
        else if (owner->floating_state_ == "processing") status = L"Working on your request";
        else if (owner->floating_state_ == "speaking") status = L"Speaking - click to stop";
        SetTextColor(dc, RGB(195, 231, 220));
        RECT status_rect{76, 30, bounds.right - 12, 49};
        DrawTextW(dc, status, -1, &status_rect,
                  DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        const std::wstring transcript = ToWide(owner->floating_transcript_);
        SetTextColor(dc, RGB(255, 255, 255));
        RECT transcript_rect{76, 50, bounds.right - 12, bounds.bottom - 8};
        DrawTextW(dc, transcript.c_str(), static_cast<int>(transcript.size()),
                  &transcript_rect,
                  DT_LEFT | DT_TOP | DT_WORDBREAK | DT_END_ELLIPSIS);
        SelectObject(dc, old_font);
        DeleteObject(title_font);
      }
      EndPaint(window, &paint);
      return 0;
    }
    case WM_TIMER:
      if (owner != nullptr && wparam == kFloatingAnimationTimer) {
        owner->floating_animation_phase_ =
            (owner->floating_animation_phase_ + 1) % 24;
        InvalidateRect(window, nullptr, FALSE);
        return 0;
      }
      break;
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
      } else if (call.method_name() == "startVoiceAccess") {
        result->Success(
            flutter::EncodableValue(StartVoiceAccessIfNeeded()));
      } else if (call.method_name() == "markVoiceAccessListening") {
        if (IsVoiceAccessRunning()) g_voice_access_known_state = 1;
        result->Success(flutter::EncodableValue(
            g_voice_access_known_state == 1));
      } else if (call.method_name() == "pauseVoiceAccess") {
        // Only change a state Liyabona can identify. Do not toggle Voice Access
        // when it may already be asleep or its status is unknown.
        const bool paused = IsVoiceAccessRunning() &&
            g_voice_access_known_state == 1 &&
            !g_voice_access_paused_by_app && SendVoiceAccessSleepShortcut();
        if (paused) {
          g_voice_access_known_state = 0;
          g_voice_access_paused_by_app = true;
        }
        result->Success(flutter::EncodableValue(paused));
      } else if (call.method_name() == "resumeVoiceAccess") {
        const bool resumed = g_voice_access_paused_by_app &&
            IsVoiceAccessRunning() && SendVoiceAccessSleepShortcut();
        if (resumed) {
          g_voice_access_known_state = 1;
          g_voice_access_paused_by_app = false;
        }
        result->Success(flutter::EncodableValue(resumed));
      } else if (call.method_name() == "focusMainWindow") {
        ShowWindow(GetHandle(), SW_RESTORE);
        SetForegroundWindow(GetHandle());
        result->Success(flutter::EncodableValue(true));
      } else if (call.method_name() == "transcribeOffline") {
          const auto* arguments = call.arguments() == nullptr
              ? nullptr
              : std::get_if<flutter::EncodableMap>(call.arguments());
          const std::vector<uint8_t>* pcm = nullptr;
          int sample_rate = 0;
          int channels = 0;
          if (arguments != nullptr) {
            for (const auto& entry : *arguments) {
              const auto* key = std::get_if<std::string>(&entry.first);
              if (key == nullptr) continue;
              if (*key == "pcm") pcm = std::get_if<std::vector<uint8_t>>(&entry.second);
              if (*key == "sampleRate") {
                const auto* value = std::get_if<int32_t>(&entry.second);
                if (value != nullptr) {
                  sample_rate = *value;
                } else if (const auto* wide_value =
                               std::get_if<int64_t>(&entry.second)) {
                  sample_rate = static_cast<int>(*wide_value);
                }
              }
              if (*key == "channels") {
                const auto* value = std::get_if<int32_t>(&entry.second);
                if (value != nullptr) {
                  channels = *value;
                } else if (const auto* wide_value =
                               std::get_if<int64_t>(&entry.second)) {
                  channels = static_cast<int>(*wide_value);
                }
              }
            }
          }
          if (pcm == nullptr || sample_rate <= 0 || channels <= 0) {
            result->Error("invalid_audio", "Offline speech audio was invalid.");
            return;
          }
          const HWND result_window = GetHandle();
          auto shared_result =
              std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                  std::move(result));
          std::vector<uint8_t> audio = *pcm;
          std::thread([result_window, shared_result,
                       audio = std::move(audio), sample_rate,
                       channels]() mutable {
            auto* response = new OfflineTranscriptionResult{
                shared_result,
                TranscribeOfflinePcm16(audio, sample_rate, channels)};
            if (!PostMessageW(result_window, kOfflineTranscriptionReady, 0,
                              reinterpret_cast<LPARAM>(response))) {
              delete response;
            }
          }).detach();
        } else if (call.method_name() == "openApprovedApp") {
          const std::string* app_id =
              call.arguments() == nullptr
                  ? nullptr
                  : std::get_if<std::string>(call.arguments());
          const wchar_t* target = nullptr;
          if (app_id != nullptr) {
            if (*app_id == "outlook") target = L"outlook.exe";
            if (*app_id == "word") target = L"winword.exe";
            if (*app_id == "excel") target = L"excel.exe";
            if (*app_id == "powerpoint") target = L"powerpnt.exe";
            if (*app_id == "teams") target = L"ms-teams:";
            if (*app_id == "onenote") target = L"onenote:";
            if (*app_id == "edge") target = L"msedge.exe";
            if (*app_id == "chrome") target = L"chrome.exe";
            if (*app_id == "zoom") target = L"Zoom.exe";
            if (*app_id == "notepad") target = L"notepad.exe";
            if (*app_id == "calculator") target = L"calc.exe";
            if (*app_id == "file_explorer") target = L"explorer.exe";
            if (*app_id == "pdf_reader") target = L"AcroRd32.exe";
            if (*app_id == "photos") target = L"ms-photos:";
          }
          HINSTANCE launch_result =
              target == nullptr
                  ? nullptr
                  : ShellExecuteW(GetHandle(), L"open", target, nullptr,
                                  nullptr, SW_SHOWNORMAL);
          // Acrobat Reader has used both executable names across releases.
          if (app_id != nullptr && *app_id == "pdf_reader" &&
              reinterpret_cast<INT_PTR>(launch_result) <= 32) {
            launch_result = ShellExecuteW(GetHandle(), L"open", L"Acrobat.exe",
                                          nullptr, nullptr, SW_SHOWNORMAL);
          }
          result->Success(flutter::EncodableValue(
              reinterpret_cast<INT_PTR>(launch_result) > 32));
        } else if (call.method_name() == "searchEdge") {
          const std::string* url = call.arguments() == nullptr
              ? nullptr
              : std::get_if<std::string>(call.arguments());
          const std::wstring wide_url = url == nullptr ? L"" : ToWide(*url);
          const bool approved_url = wide_url.rfind(
              L"https://www.bing.com/search?", 0) == 0;
          std::wstring parameters = L"\"" + wide_url + L"\"";
          const auto launch_result = approved_url
              ? ShellExecuteW(GetHandle(), L"open", L"msedge.exe",
                              parameters.c_str(), nullptr, SW_SHOWNORMAL)
              : nullptr;
          result->Success(flutter::EncodableValue(
              reinterpret_cast<INT_PTR>(launch_result) > 32));
        } else if (call.method_name() == "createWordDocument" ||
                   call.method_name() == "createPowerPoint") {
          const auto* arguments = call.arguments() == nullptr
              ? nullptr
              : std::get_if<flutter::EncodableMap>(call.arguments());
          std::wstring title;
          std::wstring body;
          if (arguments != nullptr) {
            for (const auto& entry : *arguments) {
              const auto* key = std::get_if<std::string>(&entry.first);
              const auto* value = std::get_if<std::string>(&entry.second);
              if (key == nullptr || value == nullptr) continue;
              if (*key == "title") title = ToWide(*value);
              if (*key == "body") body = ToWide(*value);
            }
          }
          if (title.empty() || body.empty()) {
            result->Error("invalid_document", "A title and non-empty draft are required.");
            return;
          }
          if (title.size() > 120 || body.size() > 24000) {
            result->Error("document_too_large", "The draft exceeds the local document size limit.");
            return;
          }
          const bool create_word = call.method_name() == "createWordDocument";
          const HWND result_window = GetHandle();
          auto shared_result =
              std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>>(
                  std::move(result));
          std::thread([result_window, shared_result, title = std::move(title),
                       body = std::move(body), create_word]() mutable {
            OfficeOperationResult operation;
            try {
              operation = create_word ? CreateWordDocument(title, body)
                                      : CreatePowerPoint(title, body);
            } catch (const std::exception&) {
              operation.error = L"Office document creation failed unexpectedly.";
            } catch (...) {
              operation.error = L"Office document creation failed unexpectedly.";
            }
            auto* response = new OfficeDocumentResponse{shared_result,
                                                        std::move(operation)};
            if (!PostMessageW(result_window, kOfficeDocumentReady, 0,
                              reinterpret_cast<LPARAM>(response))) {
              delete response;
            }
          }).detach();
        } else if (call.method_name() == "setFloatingState") {
          std::string state = "idle";
          std::string transcript;
          const auto* arguments = call.arguments() == nullptr
              ? nullptr
              : std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            for (const auto& entry : *arguments) {
              const auto* key = std::get_if<std::string>(&entry.first);
              const auto* value = std::get_if<std::string>(&entry.second);
              if (key == nullptr || value == nullptr) continue;
              if (*key == "state") state = *value;
              if (*key == "transcript") transcript = *value;
            }
          } else if (call.arguments() != nullptr) {
            const auto* value = std::get_if<std::string>(call.arguments());
            if (value != nullptr) state = *value;
          }
          SetFloatingState(state, transcript);
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
  emergency_stop_hotkey_registered_ = RegisterHotKey(
      GetHandle(), kEmergencyStopHotkey, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT,
      VK_ESCAPE) != 0;
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
  if (g_voice_access_paused_by_app && IsVoiceAccessRunning()) {
    SendVoiceAccessSleepShortcut();
    g_voice_access_paused_by_app = false;
    g_voice_access_known_state = 1;
  }
  if (emergency_stop_hotkey_registered_) {
    UnregisterHotKey(GetHandle(), kEmergencyStopHotkey);
    emergency_stop_hotkey_registered_ = false;
  }
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
  // Emergency cancellation takes precedence over plugin message handling.
  if (message == WM_HOTKEY && wparam == kEmergencyStopHotkey) {
    if (accessibility_channel_) {
      accessibility_channel_->InvokeMethod("emergencyStop", nullptr);
    }
    return 0;
  }
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
    case kOfflineTranscriptionReady: {
      std::unique_ptr<OfflineTranscriptionResult> response(
          reinterpret_cast<OfflineTranscriptionResult*>(lparam));
      if (!response || !response->result) return 0;
      flutter::EncodableMap payload;
      payload[flutter::EncodableValue("available")] = flutter::EncodableValue(
          response->transcription.model_available);
      payload[flutter::EncodableValue("text")] =
          flutter::EncodableValue(response->transcription.text);
      payload[flutter::EncodableValue("confidence")] =
          flutter::EncodableValue(response->transcription.confidence);
      response->result->Success(flutter::EncodableValue(payload));
      return 0;
    }
    case kOfficeDocumentReady: {
      std::unique_ptr<OfficeDocumentResponse> response(
          reinterpret_cast<OfficeDocumentResponse*>(lparam));
      if (!response || !response->result) return 0;
      flutter::EncodableMap payload;
      payload[flutter::EncodableValue("success")] =
          flutter::EncodableValue(response->operation.success);
      payload[flutter::EncodableValue("path")] =
          flutter::EncodableValue(ToUtf8(response->operation.path));
      payload[flutter::EncodableValue("error")] =
          flutter::EncodableValue(ToUtf8(response->operation.error));
      response->result->Success(flutter::EncodableValue(payload));
      return 0;
    }
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
