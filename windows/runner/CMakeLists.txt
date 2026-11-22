cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Whisper.cpp is compiled into liyabona.exe as a static CPU library. This keeps
# offline transcription independent of an unsigned sidecar executable or DLL.
include(FetchContent)
set(LIYABONA_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
set(LIYABONA_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/whisper-install"
  CACHE PATH "Temporary install prefix for Whisper dependency configuration" FORCE)
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/whisper-install")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static dependencies" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(GGML_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "Use a portable CPU target" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "Avoid an extra runtime dependency" FORCE)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_VULKAN OFF CACHE BOOL "" FORCE)
set(GGML_SYCL OFF CACHE BOOL "" FORCE)
set(GGML_OPENCL OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
FetchContent_Declare(whisper_cpp
  GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
  GIT_TAG v1.7.6
  GIT_SHALLOW TRUE
  GIT_SUBMODULES ggml
  GIT_SUBMODULES_RECURSE TRUE
)
FetchContent_MakeAvailable(whisper_cpp)
set(CMAKE_INSTALL_PREFIX "${LIYABONA_INSTALL_PREFIX}")
set(CMAKE_INSTALL_PREFIX "${LIYABONA_INSTALL_PREFIX}" CACHE PATH
  "Restore the Flutter app bundle install prefix" FORCE)
unset(LIYABONA_INSTALL_PREFIX)
# whisper.cpp sets a global runtime output directory for its own CLI tools. Put
# Flutter's executable back in its standard runner/<Configuration> directory.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${LIYABONA_RUNTIME_OUTPUT_DIRECTORY}")
unset(LIYABONA_RUNTIME_OUTPUT_DIRECTORY)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "whisper_transcriber.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_compile_definitions(${BINARY_NAME} PRIVATE RECORD_WINDOWS_STATIC)

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "shell32.lib")
target_link_libraries(${BINARY_NAME} PRIVATE whisper)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# The GitHub Actions build (and local Windows builds using the helper script)
# place the model next to the executable. No model is downloaded by the app.
set(LIYABONA_WHISPER_MODEL
  "${CMAKE_CURRENT_SOURCE_DIR}/../models/ggml-small.en-q5_1.bin")
if(EXISTS "${LIYABONA_WHISPER_MODEL}")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/speech_models"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${LIYABONA_WHISPER_MODEL}"
      "$<TARGET_FILE_DIR:${BINARY_NAME}>/speech_models/ggml-small.en-q5_1.bin"
    COMMENT "Bundling the offline English speech model"
    VERBATIM)
endif()

# Build the Windows speech recognizer directly into the app executable. The
# package's Dart side remains registered normally; this avoids loading an
# unsigned speech_to_text_windows_plugin.dll at startup.
set(SPEECH_TO_TEXT_WINDOWS_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../packages/speech_to_text_windows/windows")
set(FLUTTER_TTS_WINDOWS_DIR
  "${CMAKE_CURRENT_SOURCE_DIR}/../../packages/flutter_tts/windows")
target_sources(${BINARY_NAME} PRIVATE
  "${SPEECH_TO_TEXT_WINDOWS_DIR}/speech_to_text_windows.cpp"
  "${SPEECH_TO_TEXT_WINDOWS_DIR}/speech_to_text_windows_plugin.cpp"
  "${FLUTTER_TTS_WINDOWS_DIR}/flutter_tts_plugin.cpp")
set_source_files_properties(
  "${SPEECH_TO_TEXT_WINDOWS_DIR}/speech_to_text_windows.cpp"
  "${SPEECH_TO_TEXT_WINDOWS_DIR}/speech_to_text_windows_plugin.cpp"
  "${FLUTTER_TTS_WINDOWS_DIR}/flutter_tts_plugin.cpp"
  PROPERTIES
    COMPILE_OPTIONS "/W3;/WX-;/wd4996;/wd4245;/wd4100"
    COMPILE_DEFINITIONS "WIN32_LEAN_AND_MEAN;_CRT_SECURE_NO_WARNINGS;_WINSOCK_DEPRECATED_NO_WARNINGS;FLUTTER_PLUGIN_IMPL")
target_include_directories(${BINARY_NAME} PRIVATE
  "${SPEECH_TO_TEXT_WINDOWS_DIR}"
  "${SPEECH_TO_TEXT_WINDOWS_DIR}/include"
  "${FLUTTER_TTS_WINDOWS_DIR}/include")
target_compile_options(${BINARY_NAME} PRIVATE /wd4996 /wd4245)
target_link_libraries(${BINARY_NAME} PRIVATE
  flutter_wrapper_plugin
  ole32
  oleaut32
  UIAutomationCore
  uuid
  sapi)
set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/flutter_window.cpp"
  PROPERTIES COMPILE_DEFINITIONS "FLUTTER_PLUGIN_IMPL")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
