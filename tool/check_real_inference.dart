import '../lib/local_ai/engine.dart';

Future<void> main(List<String> args) async {
  final root = args.single;
  final engine = LocalEngine(
    runtime: '$root/ai-runtime/llama-cli.exe',
    model: '$root/ai-runtime/Qwen3-0.6B-Q4_K_M.gguf',
  );
  try {
    final result = await engine
        .generate('Say hello in one short sentence.')
        .join();
    if (result.trim().isEmpty) throw StateError('Empty actual inference');
    print('REAL QWEN OUTPUT: $result');
  } finally {
    engine.dispose();
  }
}
