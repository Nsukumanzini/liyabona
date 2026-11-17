import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_receptionist/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
  });

  testWidgets('reception app opens on the AI copilot screen', (tester) async {
    await tester.pumpWidget(const ReceptionDemo());
    await tester.pump();

    expect(find.byType(ReceptionDemo), findsOneWidget);
    expect(find.text('AI copilot'), findsWidgets);
  });
}
