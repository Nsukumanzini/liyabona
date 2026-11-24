import 'dart:async';

enum VoicePhase {
  idle,
  listening,
  transcribing,
  understanding,
  awaitingClarification,
  awaitingConfirmation,
  executing,
  speaking,
  cancelled,
  error,
}

/// Request generations prevent late transcription from executing cancelled work.
class VoiceInteraction {
  VoicePhase phase = VoicePhase.idle;
  int _generation = 0;
  int get generation => _generation;
  bool isCurrent(int generation) => generation == _generation;
  void move(VoicePhase next) => phase = next;
  int begin() {
    _generation++;
    phase = VoicePhase.listening;
    return _generation;
  }

  void cancel() {
    _generation++;
    phase = VoicePhase.cancelled;
    _confirmation?.complete(false);
    _confirmation = null;
  }

  Completer<bool>? _confirmation;
  String confirmationDetails = '';
  bool get awaitingConfirmation => _confirmation != null;
  Future<bool> confirm(String details) {
    if (_confirmation != null) throw StateError('Confirmation already pending');
    confirmationDetails = details;
    phase = VoicePhase.awaitingConfirmation;
    _confirmation = Completer<bool>();
    return _confirmation!.future;
  }

  bool answer(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .trim();
    final yes = {'yes', 'confirm', 'yes please'}.contains(normalized);
    final no = {'no', 'cancel', 'change it', 'go back'}.contains(normalized);
    if (_confirmation == null || (!yes && !no)) return false;
    _confirmation!.complete(yes);
    _confirmation = null;
    phase = yes ? VoicePhase.executing : VoicePhase.cancelled;
    return true;
  }
}
