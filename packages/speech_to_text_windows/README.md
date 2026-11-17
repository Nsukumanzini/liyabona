# speech_to_text_windows

The Windows implementation of the speech_to_text plugin.


## Usage

See [speech_to_text](https://github.com/csdcorp/speech_to_text/blob/main/speech_to_text/README.md)
# Liyabona Windows speech integration

This local package keeps `speech_to_text`'s Windows Dart implementation. Its SAPI native source is compiled into the Liyabona runner executable by `windows/runner/CMakeLists.txt`, so the app does not load a separate speech recognition plugin DLL.

The native source is based on `speech_to_text_windows` 1.0.1 and retains its upstream license in `LICENSE`.
