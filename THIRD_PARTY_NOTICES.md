# Third-party notices

## whisper.cpp

Liyabona uses whisper.cpp v1.7.6 for local Windows speech recognition. It is
compiled statically into the Liyabona executable. whisper.cpp is distributed
under the MIT License: <https://github.com/ggerganov/whisper.cpp/blob/v1.7.6/LICENSE>.

## Whisper small English model

The Windows ZIP includes `ggml-small.en-q5_1.bin`, a quantized English speech
recognition model distributed by the whisper.cpp project (source filename
`ggml-model-whisper-small.en-q5_1.bin`; 190,098,681 bytes; SHA-256
`bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30`). The
model is not fine-tuned for South African English. Model source:
<https://huggingface.co/ggerganov/whisper.cpp/tree/e7c63091148293a457a91f9b127a86250683f6b9>.
