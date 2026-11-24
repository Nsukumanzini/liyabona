import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Single-request, CPU-only llama.cpp CLI transport. No listening network port.
class LocalEngine {
  Process? _process;
  bool _busy = false;
  int _generation = 0;
  final String runtime;
  final String model;
  LocalEngine({required this.runtime, required this.model});

  Future<void> validate() async {
    if (!await File(runtime).exists())
      throw StateError('Local AI runtime is missing.');
    final file = File(model);
    if (!await file.exists()) throw StateError('Local AI model is missing.');
    final input = await file.open();
    try {
      final header = await input.read(4);
      if (ascii.decode(header, allowInvalid: true) != 'GGUF') {
        throw StateError('Local AI model header is invalid.');
      }
    } finally {
      await input.close();
    }
  }

  Stream<String> generate(
    String prompt, {
    int context = 1024,
    int threads = 2,
    int maximumTokens = 128,
    Duration timeout = const Duration(seconds: 90),
  }) async* {
    if (_busy) throw StateError('Local AI is already working.');
    if (context < 512 ||
        context > 2048 ||
        threads < 1 ||
        threads > 8 ||
        maximumTokens < 1 ||
        maximumTokens > 512)
      throw ArgumentError('Invalid inference limits');
    _busy = true;
    final generation = ++_generation;
    Timer? timer;
    StreamSubscription<String>? errors;
    try {
      await validate();
      final process = await Process.start(runtime, [
        '-m',
        model,
        '-c',
        '$context',
        '-t',
        '$threads',
        '-n',
        '$maximumTokens',
        '-ngl',
        '0',
        '--no-display-prompt',
        '--simple-io',
        '--no-conversation',
        '-p',
        '<|im_start|>system\nYou assist a blind receptionist at Gert Sibande TVET College, Ermelo Campus. Be concise. Never claim actions or invent records. /no_think<|im_end|>\n<|im_start|>user\n$prompt /no_think<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n',
      ], runInShell: false);
      _process = process;
      await process.stdin.close();
      if (generation != _generation) {
        process.kill();
        return;
      }
      errors = process.stderr.transform(utf8.decoder).listen((_) {});
      var timedOut = false;
      timer = Timer(timeout, () {
        timedOut = true;
        process.kill();
      });
      await for (final chunk in process.stdout.transform(utf8.decoder)) {
        if (generation != _generation) break;
        yield chunk;
      }
      final code = await process.exitCode;
      if (timedOut) throw TimeoutException('Local AI took too long.');
      if (generation == _generation && code != 0)
        throw StateError('Local AI process failed.');
    } finally {
      timer?.cancel();
      _process?.kill();
      await errors?.cancel();
      _process = null;
      _busy = false;
    }
  }

  void cancel() {
    _generation++;
    _process?.kill();
  }

  void dispose() => cancel();
}

String cleanLocalReply(String text) => text
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
    .replaceAll(RegExp(r'\[end of text\]|<\|[^>]+\|>'), '')
    .trim();
