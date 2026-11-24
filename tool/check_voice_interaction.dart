import '../lib/voice/interaction.dart';

Future<void> main() async {
  final voice = VoiceInteraction();
  final request = voice.begin();
  if (!voice.isCurrent(request)) throw StateError('New request rejected');
  voice.cancel();
  if (voice.isCurrent(request)) throw StateError('Cancelled request still valid');
  final denied = voice.confirm('Delete note');
  if (voice.answer('noise')) throw StateError('Noise approved operation');
  if (!voice.answer('No')) throw StateError('No ignored');
  if (await denied) throw StateError('Declined operation approved');
  final approved = voice.confirm('Delete note');
  voice.answer('Yes');
  if (!await approved) throw StateError('Yes ignored');
  final cancelled = voice.confirm('Delete note');
  voice.cancel();
  if (await cancelled) throw StateError('Cancellation approved operation');
  print('Voice interaction checks passed.');
}
