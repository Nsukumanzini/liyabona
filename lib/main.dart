import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xFF19352F);
const forest = Color(0xFF17594E);
const teal = Color(0xFF13796D);
const mint = Color(0xFFE6F3EF);
const paper = Color(0xFFF5F7F5);
const line = Color(0xFFE7ECE9);
const amber = Color(0xFFFFF1D8);
const redSoft = Color(0xFFFFE9E5);
const _assistantEndpoint =
    'https://campuscare-reception-demo.vercel.app/api/assistant';
const _windowsAccessibilityChannel = MethodChannel('liyabona/accessibility');

void main() => runApp(const LiyabonaApp());

class LiyabonaApp extends StatefulWidget {
  const LiyabonaApp({super.key});
  @override
  State<LiyabonaApp> createState() => _LiyabonaAppState();
}

class _LiyabonaAppState extends State<LiyabonaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _speech = stt.SpeechToText();
  final _audioRecorder = AudioRecorder();
  final _tts = FlutterTts();
  final _knowledgeController = TextEditingController();
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _audioCheckTimer;
  BytesBuilder _audioBuffer = BytesBuilder(copy: false);
  DateTime? _audioStartedAt;
  DateTime? _lastVoicedAt;
  int _voicedSampleCount = 0;
  int _recordingSampleRate = 16000;
  int _recordingChannels = 1;
  bool _forceOfflineSpeech = false;
  bool _finishingAudio = false;
  String? _lastMutationNotice;
  bool _awaitingSessionChoice = false;
  Future<void> _offlineDataReady = Future<void>.value();
  Future<void> _knowledgeReady = Future<void>.value();
  bool _speechReady = false;
  bool _preferOnDeviceSpeech = true;
  String? _speechLocale;
  bool _voiceSession = false;
  bool _listening = false;
  bool _processing = false;
  bool _highContrast = false;
  bool _largeText = false;
  bool _assistantBusy = false;
  String _assistantError = '';
  bool _ttsSpeaking = false;
  bool _greetingPlaying = false;
  int _listenFailures = 0;
  Timer? _listenRestartTimer;
  Timer? _wakeWordRestartTimer;
  bool _wakeWordEnabled = false;
  bool _wakeWordListening = false;
  bool _wakeLaunchInProgress = false;
  bool _assistantPopupOpen = false;
  String _lastSpeechText = '';
  String _windowsScreenText = '';
  String _windowsScreenTitle = '';
  String _lastWindowsScreenChunk = '';
  int _windowsScreenOffset = 0;
  int _speechGeneration = 0;
  StateSetter? _popupRebuild;
  String _transcript = '';
  String _heardPhrase = '';
  String _interpretation = '';
  double? _matchConfidence;
  List<String> _pendingChoices = [];
  String _page = 'AI copilot';
  String _knowledgeText = '';
  String _search = '';
  int _chatCount = 0;
  final List<_Appointment> _appointments = [];
  final List<_Call> _calls = [];
  final List<_Note> _notes = [];
  final List<_Enquiry> _enquiries = [];
  final List<_Document> _documents = [];
  final List<_EmailDraft> _emails = [];
  String? _mailboxAddress;
  String? _mailboxProvider;
  final List<_Visitor> _visitors = [];
  final List<_ReceptionTask> _tasks = [];
  final List<_ChatLine> _chat = [];

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _appointments.addAll([
      _Appointment(
        'Welcome and registration help',
        'Lerato Mokoena',
        DateTime(now.year, now.month, now.day, 9, 30),
        'Office 2 · Main block',
        'Registration support',
      ),
      _Appointment(
        'Course change discussion',
        'Thabo Khumalo',
        DateTime(now.year, now.month, now.day, 11, 0),
        'Office 2 · Main block',
        'Academic support',
      ),
      _Appointment(
        'Financial aid follow-up',
        'Amina Dlamini',
        DateTime(now.year, now.month, now.day, 14, 15),
        'Online · phone call',
        'Financial aid',
      ),
      _Appointment(
        'New learner orientation',
        'Neo Nkosi',
        DateTime(now.year, now.month, now.day + 1, 10, 0),
        'Student Support office',
        'Orientation',
      ),
    ]);
    _calls.addAll([
      _Call(
        'Nomsa Maseko',
        '071 555 0192',
        'Asked about a replacement student card.',
        true,
        'High',
        DateTime(now.year, now.month, now.day, 8, 45),
      ),
      _Call(
        'Peter Dube',
        '072 555 0144',
        'Needs a call back about transport support.',
        true,
        'Normal',
        DateTime(now.year, now.month, now.day, 9, 12),
      ),
      _Call(
        'Unknown caller',
        '011 555 0120',
        'Asked for the student support office hours.',
        false,
        'Low',
        DateTime(now.year, now.month, now.day, 9, 38),
      ),
    ]);
    _notes.addAll([
      _Note(
        'Orientation checklist',
        'Confirm room access, learner list and printed welcome packs.',
        DateTime(now.year, now.month, now.day, 8, 10),
      ),
      _Note(
        'Morning handover',
        'Follow up on two calls and prepare the replacement card information.',
        DateTime(now.year, now.month, now.day, 8, 25),
      ),
    ]);
    _enquiries.addAll([
      _Enquiry(
        'Lerato Mokoena',
        'Registration',
        'Learner needs help finding the correct registration form.',
        'In progress',
        'Normal',
      ),
      _Enquiry(
        'Sibusiso Ndlovu',
        'Accessibility',
        'Asked for information about accessible campus routes.',
        'Waiting',
        'High',
      ),
      _Enquiry(
        'Amina Dlamini',
        'Financial aid',
        'Needs an update about her bursary documents.',
        'New',
        'Normal',
      ),
      _Enquiry(
        'Thabo Khumalo',
        'Academic support',
        'Requested a meeting about changing courses.',
        'New',
        'Low',
      ),
    ]);
    _documents.addAll([
      _Document(
        'Appointment confirmation',
        'Prepared for Lerato Mokoena',
        DateTime(now.year, now.month, now.day, 8, 30),
      ),
      _Document(
        'Call-back message',
        'Prepared for Student Support Services',
        DateTime(now.year, now.month, now.day, 8, 55),
      ),
    ]);
    _emails.add(
      _EmailDraft(
        'Student Support Manager',
        'Follow-up on learner registration assistance',
        'Dear Student Support Manager,\n\nI am following up on the learner registration assistance discussed at reception. Please let me know if any further information is needed.\n\nKind regards,\nStudent Support Reception',
        DateTime(now.year, now.month, now.day, 9, 5),
      ),
    );
    _visitors.addAll([
      _Visitor(
        'Walk-in visitor',
        'Student Support',
        'Registration question',
        DateTime.now(),
      ),
    ]);
    _tasks.addAll([
      _ReceptionTask(
        'Prepare the welcome packs',
        'Confirm the learner list and room access.',
        DateTime.now(),
        false,
      ),
      _ReceptionTask(
        'Return transport support call',
        'Call Peter Dube back.',
        DateTime.now(),
        false,
      ),
      _ReceptionTask(
        'File yesterday’s handover',
        'Move completed items to the daily folder.',
        DateTime.now(),
        true,
      ),
    ]);
    _chat.add(
      const _ChatLine(
        false,
        'Hello, I’m Liyabona AI. Tell me what you need. I can open a screen, capture a note, add a task, organise visitor check-in, log a call, schedule an appointment, or answer a reception question.',
      ),
    );
    if (_isWindowsDesktop) _offlineDataReady = _loadOfflineData();
    _knowledgeReady = _loadKnowledge();
    if (_isWindowsDesktop) {
      _windowsAccessibilityChannel.setMethodCallHandler(
        _handleWindowsAccessibilityCall,
      );
      unawaited(_loadWakeWordPreference());
    }
    _tts.setLanguage('en-ZA');
    _tts.setSpeechRate(.5);
    _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() {
      _ttsSpeaking = true;
      _refreshAssistantPopup();
    });
    _tts.setCompletionHandler(() {
      _ttsSpeaking = false;
      _refreshAssistantPopup();
    });
    _tts.setCancelHandler(() {
      _ttsSpeaking = false;
      _refreshAssistantPopup();
    });
    _tts.setErrorHandler((_) {
      _ttsSpeaking = false;
      _refreshAssistantPopup();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_speak('Hello, I hope you are doing well'));
    });
  }

  Future<void> _loadKnowledge() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString('liyabona_knowledge_v1') ?? '';
      if (!mounted) return;
      setState(() {
        _knowledgeText = value;
        _knowledgeController.text = value;
      });
    } catch (_) {
      // Keep the Knowledge page editable if local storage is unavailable.
    }
  }

  Future<Object?> _handleWindowsAccessibilityCall(MethodCall call) async {
    if (call.method == 'activateAssistant') {
      await _handleAssistantButton(showPopup: false);
      return null;
    }
    if (call.method != 'activeWindowText' || call.arguments is! Map) return null;
    final payload = Map<Object?, Object?>.from(call.arguments as Map);
    final title = payload['title']?.toString().trim() ?? '';
    final text = payload['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      const message = 'I could not read text from that app.';
      _announce(message);
      await _speak(message);
      return null;
    }
    _cacheWindowsScreenText(title, text);
    await _speakWindowsScreenChunk();
    return null;
  }

  bool _isWindowsScreenReadCommand(String command) =>
      RegExp(
        r'^(?:(?:please|can you|could you)\s+)?(?:read(?:\s+(?:(?:the|this|my|current|active)\s+)?(?:screen|window|app|email|message|document|page))?|ready)[.!? ]*$',
      ).hasMatch(command.trim().toLowerCase());

  bool _isContinueScreenReadCommand(String command) =>
      RegExp(
        r'^(continue(?: reading)?|read more|read the next (?:part|section)|next (?:part|section))[.!? ]*$',
      ).hasMatch(command.trim().toLowerCase());

  bool _isRepeatScreenReadCommand(String command) =>
      RegExp(
        r'^(repeat(?: that| reading| the last part)?|read that again|repeat last part)[.!? ]*$',
      ).hasMatch(command.trim().toLowerCase());

  void _cacheWindowsScreenText(String title, String text) {
    _windowsScreenTitle = title.trim().isEmpty ? 'the active app' : title.trim();
    _windowsScreenText = text.trim();
    _windowsScreenOffset = 0;
    _lastWindowsScreenChunk = '';
  }

  String _takeNextWindowsScreenChunk() {
    const chunkLimit = 1000;
    while (_windowsScreenOffset < _windowsScreenText.length &&
        _windowsScreenText[_windowsScreenOffset].trim().isEmpty) {
      _windowsScreenOffset++;
    }
    if (_windowsScreenOffset >= _windowsScreenText.length) return '';
    final remaining = _windowsScreenText.substring(_windowsScreenOffset);
    if (remaining.length <= chunkLimit) {
      _windowsScreenOffset = _windowsScreenText.length;
      return remaining.trim();
    }

    final candidate = remaining.substring(0, chunkLimit);
    var boundary = candidate.lastIndexOf(RegExp(r'[.!?]\s'));
    if (boundary < chunkLimit * .55) boundary = candidate.lastIndexOf(' ');
    if (boundary <= 0) boundary = chunkLimit;
    final chunk = remaining.substring(0, boundary + 1).trim();
    _windowsScreenOffset += boundary + 1;
    return chunk;
  }

  Future<void> _speakWindowsScreenChunk({bool repeatLast = false}) async {
    final chunk = repeatLast
        ? _lastWindowsScreenChunk
        : _takeNextWindowsScreenChunk();
    if (chunk.isEmpty) {
      const message = 'There is no more screen text to read.';
      _transcript = message;
      _refreshAssistantPopup();
      await _speak(message);
      return;
    }
    if (!repeatLast) _lastWindowsScreenChunk = chunk;
    final heading = _windowsScreenTitle.isEmpty
        ? 'the active app'
        : _windowsScreenTitle;
    final hasMore = _windowsScreenOffset < _windowsScreenText.length;
    final prompt = hasMore
        ? ' Activate the assistant again and say continue reading for the next part, or repeat to hear this part again.'
        : ' This is the end of the readable text.';
    _transcript = repeatLast
        ? 'Repeating the last section from $heading.'
        : 'Reading a section from $heading.';
    _refreshAssistantPopup();
    _stopSpeaking();
    await _speak('Reading $heading. $chunk.$prompt');
  }

  Future<void> _readActiveWindowsScreen({
    bool continueReading = false,
    bool repeatLast = false,
  }) async {
    await _speech.stop();
    _listening = false;
    _processing = true;
    _refreshAssistantPopup();
    try {
      if (!continueReading && !repeatLast) {
        final payload = await _windowsAccessibilityChannel
            .invokeMapMethod<String, String>('readActiveApp');
        _cacheWindowsScreenText(
          payload?['title']?.trim() ?? '',
          payload?['text']?.trim() ?? '',
        );
      }
      if (_windowsScreenText.isEmpty) {
        const message = 'I could not read text from that app.';
        _transcript = message;
        if (mounted) setState(() => _listening = false);
        await _speak(message);
      } else {
        // External app text stays on this PC and is never added to chat or
        // sent to the AI service. The text cache is cleared on each new read.
        await _speakWindowsScreenChunk(repeatLast: repeatLast);
      }
    } on PlatformException {
      const message = 'I could not read text from that app.';
      _transcript = message;
      await _speak(message);
    } catch (_) {
      const message = 'I could not read text from that app.';
      _transcript = message;
      await _speak(message);
    } finally {
      _processing = false;
      _refreshAssistantPopup();
      if (_voiceSession && mounted) await _stopVoiceAfterTask();
    }
  }

  Future<void> _loadWakeWordPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      if (!mounted || preferences.getBool('liyabona_wake_word_v1') != true) {
        return;
      }
      setState(() => _wakeWordEnabled = true);
      await _startWakeWordListening();
    } catch (_) {
      // Voice wake stays off if the saved preference cannot be read.
    }
  }

  Future<void> _setWakeWordEnabled(bool enabled) async {
    if (!_isWindowsDesktop) return;
    setState(() {
      _wakeWordEnabled = enabled;
      _assistantError = '';
    });
    _refreshAssistantPopup();
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await preferences.setBool('liyabona_wake_word_v1', enabled);
    } catch (_) {}

    if (enabled) {
      _announce(
        'Wake word enabled. The microphone will listen locally for Assist while Liyabona is open. Say Assist to start a voice session.',
      );
      await _startWakeWordListening();
    } else {
      _wakeWordRestartTimer?.cancel();
      _wakeWordListening = false;
      if (!_voiceSession) await _speech.stop();
      _refreshAssistantPopup();
      _announce('Wake word is off. The microphone is no longer listening.');
    }
  }

  Future<void> _startWakeWordListening() async {
    if (!_isWindowsDesktop || !_wakeWordEnabled || _voiceSession ||
        _wakeWordListening || _wakeLaunchInProgress || _assistantBusy ||
        _processing || _ttsSpeaking || !mounted) return;
    _wakeWordRestartTimer?.cancel();
    _wakeWordListening = true;
    _refreshAssistantPopup();
    try {
      final initialized = await _speech.initialize(
        onError: (error) {
          if (!mounted || !_wakeWordEnabled || _voiceSession) return;
          _wakeWordListening = false;
          _assistantError =
              'Wake word recognition stopped. Check Windows speech and microphone settings.';
          _refreshAssistantPopup();
        },
        onStatus: (status) {
          if (!mounted || !_wakeWordEnabled || _voiceSession) return;
          if (status == 'listening') {
            _wakeWordListening = true;
            _refreshAssistantPopup();
          } else if (status == 'done' || status == 'notListening') {
            _wakeWordListening = false;
            _refreshAssistantPopup();
            _scheduleWakeWordRestart();
          }
        },
      );
      if (!initialized) {
        _wakeWordListening = false;
        _assistantError =
            'Windows speech recognition is unavailable for the Assist wake word.';
        _refreshAssistantPopup();
        return;
      }

      try {
        final locales = await _speech.locales();
        _speechLocale = const ['en-ZA', 'en-GB', 'en-US'].firstWhere(
          (preferred) => locales.any(
            (locale) => locale.localeId.replaceAll('_', '-') == preferred,
          ),
          orElse: () => '',
        );
        if (_speechLocale!.isEmpty) _speechLocale = null;
      } catch (_) {}

      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _speechLocale,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 2),
          partialResults: false,
          cancelOnError: false,
          onDevice: true,
        ),
        onResult: (result) {
          if (!mounted || !_wakeWordEnabled || _voiceSession ||
              !result.finalResult) {
            return;
          }
          final recognized = result.recognizedWords
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z ]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (recognized != 'assist') return;
          _wakeWordListening = false;
          _wakeLaunchInProgress = true;
          _wakeWordRestartTimer?.cancel();
          _refreshAssistantPopup();
          unawaited(
            _speech.stop().whenComplete(() {
              if (mounted) unawaited(_handleAssistantButton());
            }),
          );
        },
      );
    } catch (_) {
      _wakeWordListening = false;
      _assistantError =
          'Could not start the Assist wake word. Check Windows microphone access.';
      _refreshAssistantPopup();
    }
  }

  void _scheduleWakeWordRestart() {
    if (!_wakeWordEnabled || _voiceSession || _wakeWordListening ||
        _wakeLaunchInProgress || _assistantBusy || _processing || !mounted ||
        _ttsSpeaking || (_wakeWordRestartTimer?.isActive ?? false)) {
      return;
    }
    _wakeWordRestartTimer = Timer(const Duration(milliseconds: 900), () {
      if (_wakeWordEnabled && !_voiceSession && mounted) {
        unawaited(_startWakeWordListening());
      }
    });
  }

  Future<void> _saveKnowledge(String value) async {
    final cleaned = value.trim();
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString('liyabona_knowledge_v1', cleaned);
      if (!mounted) return;
      setState(() => _knowledgeText = cleaned);
      _announce(
        saved
            ? 'Knowledge saved on this device.'
            : 'Could not save knowledge. Please try again.',
      );
    } catch (_) {
      if (mounted) _announce('Could not save knowledge. Please try again.');
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('liyabona_offline_records_v1');
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      DateTime readDate(Map<String, dynamic> value, String key) =>
          DateTime.tryParse(value[key]?.toString() ?? '') ?? DateTime.now();
      String readText(
        Map<String, dynamic> value,
        String key, [
        String fallback = '',
      ]) => value[key]?.toString() ?? fallback;
      List<T> readItems<T>(String key, T Function(Map<String, dynamic>) build) {
        final values = decoded[key];
        if (values is! List) return <T>[];
        return values
            .whereType<Map>()
            .map((item) => build(Map<String, dynamic>.from(item)))
            .toList();
      }

      final appointments = readItems(
        'appointments',
        (v) => _Appointment(
          readText(v, 'title'),
          readText(v, 'name'),
          readDate(v, 'when'),
          readText(v, 'location'),
          readText(v, 'category'),
        ),
      );
      final calls = readItems(
        'calls',
        (v) => _Call(
          readText(v, 'caller'),
          readText(v, 'phone'),
          readText(v, 'reason'),
          v['callback'] == true,
          readText(v, 'priority', 'Normal'),
          readDate(v, 'when'),
        ),
      );
      final notes = readItems(
        'notes',
        (v) => _Note(
          readText(v, 'title'),
          readText(v, 'body'),
          readDate(v, 'when'),
        ),
      );
      final enquiries = readItems(
        'enquiries',
        (v) => _Enquiry(
          readText(v, 'name'),
          readText(v, 'category'),
          readText(v, 'detail'),
          readText(v, 'status'),
          readText(v, 'priority', 'Normal'),
        ),
      );
      final documents = readItems(
        'documents',
        (v) => _Document(
          readText(v, 'title'),
          readText(v, 'summary'),
          readDate(v, 'when'),
        ),
      );
      final emails = readItems(
        'emails',
        (v) => _EmailDraft(
          readText(v, 'recipient'),
          readText(v, 'subject'),
          readText(v, 'body'),
          readDate(v, 'when'),
        ),
      );
      final visitors = readItems(
        'visitors',
        (v) => _Visitor(
          readText(v, 'name'),
          readText(v, 'host'),
          readText(v, 'purpose'),
          readDate(v, 'checkedIn'),
        )..checkedOut = DateTime.tryParse(readText(v, 'checkedOut')),
      );
      final tasks = readItems(
        'tasks',
        (v) => _ReceptionTask(
          readText(v, 'title'),
          readText(v, 'detail'),
          readDate(v, 'created'),
          v['done'] == true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _appointments
          ..clear()
          ..addAll(appointments);
        _calls
          ..clear()
          ..addAll(calls);
        _notes
          ..clear()
          ..addAll(notes);
        _enquiries
          ..clear()
          ..addAll(enquiries);
        _documents
          ..clear()
          ..addAll(documents);
        _emails
          ..clear()
          ..addAll(emails);
        _visitors
          ..clear()
          ..addAll(visitors);
        _tasks
          ..clear()
          ..addAll(tasks);
        _mailboxAddress = decoded['mailboxAddress']?.toString();
        _mailboxProvider = decoded['mailboxProvider']?.toString();
      });
    } catch (_) {
      // Keep the app usable with its saved records if local data is damaged.
    }
  }

  Future<bool> _saveOfflineData() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.setString(
        'liyabona_offline_records_v1',
        jsonEncode({
          'appointments': _appointments
              .map(
                (v) => {
                  'title': v.title,
                  'name': v.name,
                  'when': v.when.toIso8601String(),
                  'location': v.location,
                  'category': v.category,
                },
              )
              .toList(),
          'calls': _calls
              .map(
                (v) => {
                  'caller': v.caller,
                  'phone': v.phone,
                  'reason': v.reason,
                  'callback': v.callback,
                  'priority': v.priority,
                  'when': v.when.toIso8601String(),
                },
              )
              .toList(),
          'notes': _notes
              .map(
                (v) => {
                  'title': v.title,
                  'body': v.body,
                  'when': v.when.toIso8601String(),
                },
              )
              .toList(),
          'enquiries': _enquiries
              .map(
                (v) => {
                  'name': v.name,
                  'category': v.category,
                  'detail': v.detail,
                  'status': v.status,
                  'priority': v.priority,
                },
              )
              .toList(),
          'documents': _documents
              .map(
                (v) => {
                  'title': v.title,
                  'summary': v.summary,
                  'when': v.when.toIso8601String(),
                },
              )
              .toList(),
          'emails': _emails
              .map(
                (v) => {
                  'recipient': v.recipient,
                  'subject': v.subject,
                  'body': v.body,
                  'when': v.when.toIso8601String(),
                },
              )
              .toList(),
          'visitors': _visitors
              .map(
                (v) => {
                  'name': v.name,
                  'host': v.host,
                  'purpose': v.purpose,
                  'checkedIn': v.checkedIn.toIso8601String(),
                  'checkedOut': v.checkedOut?.toIso8601String(),
                },
              )
              .toList(),
          'tasks': _tasks
              .map(
                (v) => {
                  'title': v.title,
                  'detail': v.detail,
                  'created': v.created.toIso8601String(),
                  'done': v.done,
                },
              )
              .toList(),
          'mailboxAddress': _mailboxAddress,
          'mailboxProvider': _mailboxProvider,
        }),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistWindowsData() async {
    if (!_isWindowsDesktop) return;
    await _offlineDataReady;
    await _saveOfflineData();
  }

  @override
  void dispose() {
    if (_isWindowsDesktop) {
      _windowsAccessibilityChannel.setMethodCallHandler(null);
    }
    _listenRestartTimer?.cancel();
    _audioCheckTimer?.cancel();
    unawaited(_audioSubscription?.cancel());
    unawaited(_audioRecorder.dispose());
    _speech.stop();
    _tts.stop();
    _knowledgeController.dispose();
    super.dispose();
  }

  List<_NavItem> get _nav => const [
    _NavItem('Home', Icons.grid_view_rounded),
    _NavItem('Calendar', Icons.calendar_month_rounded),
    _NavItem('Enquiries', Icons.assignment_outlined),
    _NavItem('Notes', Icons.sticky_note_2_outlined),
    _NavItem('Documents', Icons.description_outlined),
    _NavItem('Emails', Icons.mark_email_unread_outlined),
    _NavItem('Learners', Icons.people_alt_outlined),
    _NavItem('Knowledge', Icons.menu_book_outlined),
    _NavItem('AI copilot', Icons.auto_awesome_rounded),
    _NavItem('Visitors', Icons.badge_outlined),
    _NavItem('Tasks', Icons.task_alt_rounded),
  ];

  Future<void> _speak(String text, {bool toggle = false}) async {
    if (text.trim().isEmpty) return;
    if (_wakeWordEnabled && !_voiceSession) {
      _wakeWordRestartTimer?.cancel();
      if (_wakeWordListening) {
        _wakeWordListening = false;
        unawaited(_speech.stop());
      }
    }
    if (toggle && _ttsSpeaking && _lastSpeechText == text) {
      _stopSpeaking();
      return;
    }
    final generation = ++_speechGeneration;
    _lastSpeechText = text;
    try {
      _ttsSpeaking = false;
      await _tts.stop();
      if (generation != _speechGeneration) return;
      _ttsSpeaking = true;
      _refreshAssistantPopup();
      await _tts.speak(text);
    } catch (_) {
      if (generation != _speechGeneration) return;
      try {
        _ttsSpeaking = true;
        await _tts.setLanguage('en-ZA');
        if (generation != _speechGeneration) return;
        await _tts.speak(text);
      } catch (_) {
        if (generation == _speechGeneration) _ttsSpeaking = false;
        if (mounted)
          _announce(
            'Spoken replies are unavailable on this device. Check its speech and audio settings.',
          );
      }
    }
  }

  Future<void> _waitForSpeechToFinish() async {
    final generation = _speechGeneration;
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (_ttsSpeaking &&
        generation == _speechGeneration &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _stopSpeaking() {
    _speechGeneration++;
    _ttsSpeaking = false;
    unawaited(_tts.stop());
    _refreshAssistantPopup();
  }

  void _refreshAssistantPopup() {
    if (_isWindowsDesktop) {
      final state = _listening
          ? 'listening'
          : _wakeWordListening
          ? 'wake'
          : (_processing || _assistantBusy)
          ? 'processing'
          : _ttsSpeaking
          ? 'speaking'
          : 'idle';
      unawaited(
        _windowsAccessibilityChannel
            .invokeMethod<void>('setFloatingState', state)
            .catchError((_) {}),
      );
      _scheduleWakeWordRestart();
    }
    final rebuild = _popupRebuild;
    if (rebuild == null || !mounted) return;
    try {
      rebuild(() {});
    } catch (_) {
      _popupRebuild = null;
    }
  }

  List<Map<String, String>> get _assistantRecords => [
    ..._appointments.map(
      (v) => {
        'type': 'appointment',
        'query': v.title,
        'name': v.name,
        'dateTime': v.when.toIso8601String(),
        'location': v.location,
        'detail': v.category,
      },
    ),
    ..._calls.map(
      (v) => {
        'type': 'call',
        'query': v.caller,
        'name': v.caller,
        'phone': v.phone,
        'detail': v.reason,
        'callback': v.callback.toString(),
        'priority': v.priority,
      },
    ),
    ..._notes.map(
      (v) => {'type': 'note', 'query': v.title, 'title': v.title, 'body': v.body},
    ),
    ..._enquiries.map(
      (v) => {
        'type': 'enquiry',
        'query': v.name,
        'name': v.name,
        'category': v.category,
        'detail': v.detail,
        'status': v.status,
        'priority': v.priority,
      },
    ),
    ..._documents.map(
      (v) => {
        'type': 'document',
        'query': v.title,
        'title': v.title,
        'detail': v.summary,
      },
    ),
    ..._emails.map(
      (v) => {
        'type': 'email',
        'query': v.subject,
        'recipient': v.recipient,
        'subject': v.subject,
        'body': v.body,
      },
    ),
    ..._visitors.map(
      (v) => {
        'type': 'visitor',
        'query': v.name,
        'name': v.name,
        'host': v.host,
        'purpose': v.purpose,
        'checkedOut': (v.checkedOut != null).toString(),
      },
    ),
    ..._tasks.map(
      (v) => {
        'type': 'task',
        'query': v.title,
        'title': v.title,
        'detail': v.detail,
        'done': v.done.toString(),
      },
    ),
  ].take(80).toList();

  Future<_AssistantResult?> _askModel(
    String text, {
    String? audioBase64,
  }) async {
    if (text.trim().isEmpty && audioBase64 == null) return null;
    try {
      // Do not let a stalled preferences plugin block every AI request.
      try {
        await _knowledgeReady.timeout(const Duration(seconds: 2));
      } catch (_) {}
      final history = _chat.toList();
      if (history.isNotEmpty &&
          history.last.user &&
          text.isNotEmpty &&
          history.last.text == text) {
        history.removeLast();
      }
      final response = await http
          .post(
            Uri.parse(_assistantEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              if (audioBase64 != null) 'audio': audioBase64,
              'screen': _page,
              'summary': _pageSummary(),
              'knowledge': _knowledgeText,
              'records': _assistantRecords,
              'history': history
                  .skip(history.length > 6 ? history.length - 6 : 0)
                  .map(
                    (line) => {
                      'role': line.user ? 'user' : 'assistant',
                      'content': line.text,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(Duration(seconds: audioBase64 == null ? 30 : 8));
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        _assistantError = body is Map && body['error'] is String
            ? body['error'] as String
            : 'AI service is temporarily unavailable.';
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      _assistantError = '';
      return _AssistantResult.fromJson(data);
    } catch (_) {
      _assistantError =
          'Could not reach Liyabona AI. Check the network and try again.';
      return null;
    }
  }

  void _applyAssistantAction(_AssistantResult result) {
    final f = result.fields;
    switch (result.action) {
      case 'navigate':
        if (_nav.any((item) => item.label == result.destination)) {
          _go(result.destination);
        }
        break;
      case 'read_screen':
      case 'answer':
      case 'clarify':
        break;
      case 'create_note':
        setState(
          () => _notes.insert(
            0,
            _Note(
              f['title']?.trim().isNotEmpty == true
                  ? f['title']!.trim()
                  : 'Reception note',
              f['body']?.trim().isNotEmpty == true
                  ? f['body']!.trim()
                  : result.reply,
              DateTime.now(),
            ),
          ),
        );
        _go('Notes');
        break;
      case 'create_task':
        setState(
          () => _tasks.insert(
            0,
            _ReceptionTask(
              f['title']?.trim().isNotEmpty == true
                  ? f['title']!.trim()
                  : 'Reception follow-up',
              f['detail']?.trim().isNotEmpty == true
                  ? f['detail']!.trim()
                  : 'Added by Liyabona AI.',
              DateTime.now(),
              false,
            ),
          ),
        );
        _go('Tasks');
        break;
      case 'visitor_checkin':
        final name = f['name']?.trim() ?? '';
        if (name.isNotEmpty) {
          setState(
            () => _visitors.insert(
              0,
              _Visitor(
                name,
                f['host'] ?? 'Student Support',
                f['purpose'] ?? 'Campus visit',
                DateTime.now(),
              ),
            ),
          );
          _go('Visitors');
        }
        break;
      case 'visitor_checkout':
        final name = (f['name'] ?? '').toLowerCase();
        final found = _visitors
            .where(
              (v) =>
                  v.checkedOut == null &&
                  (name.isEmpty || v.name.toLowerCase().contains(name)),
            )
            .toList();
        if (found.isNotEmpty) {
          setState(() => found.first.checkedOut = DateTime.now());
          _go('Visitors');
        } else {
          _lastMutationNotice = 'I could not find that checked-in visitor. Nothing changed.';
        }
        break;
      case 'create_call':
        setState(
          () => _calls.insert(
            0,
            _Call(
              f['name']?.trim().isNotEmpty == true
                  ? f['name']!.trim()
                  : 'Voice caller',
              f['phone'] ?? '',
              f['detail'] ?? 'Details captured by reception.',
              f['callback'] != 'false',
              f['priority'] ?? 'Normal',
              DateTime.now(),
            ),
          ),
        );
        _go('Call log');
        break;
      case 'create_appointment':
        final parsed = DateTime.tryParse(f['dateTime'] ?? '');
        final scheduled = parsed ?? DateTime.now().add(const Duration(days: 1));
        setState(
          () => _appointments.insert(
            0,
            _Appointment(
              f['title'] ?? 'Reception appointment',
              f['name'] ?? 'Walk-in learner',
              scheduled,
              f['location'] ?? 'Student Support office',
              f['detail'] ?? '',
            ),
          ),
        );
        _go('Calendar');
        break;
      case 'create_enquiry':
        setState(
          () => _enquiries.insert(
            0,
            _Enquiry(
              f['name'] ?? 'Walk-in learner',
              f['category'] ?? 'General enquiry',
              f['detail'] ?? result.reply,
              'New',
              f['priority'] ?? 'Normal',
            ),
          ),
        );
        _go('Enquiries');
        break;
      case 'create_document':
        setState(
          () => _documents.insert(
            0,
            _Document(
              f['title'] ?? 'Reception document draft',
              f['detail'] ?? 'Draft created by Liyabona AI.',
              DateTime.now(),
            ),
          ),
        );
        _go('Documents');
        break;
      case 'create_email':
        setState(
          () => _emails.insert(
            0,
            _EmailDraft(
              f['recipient'] ?? 'Recipient to be confirmed',
              f['subject'] ?? 'Student Support follow-up',
              f['body'] ?? result.reply,
              DateTime.now(),
            ),
          ),
        );
        _go('Emails');
        break;
      case 'find_learner':
        _go('Learners');
        if ((f['name'] ?? '').isNotEmpty) setState(() => _search = f['name']!);
        break;
      case 'complete_task':
        final title = (f['title'] ?? '').toLowerCase();
        final found = _tasks
            .where(
              (task) =>
                  !task.done &&
                  (title.isEmpty || task.title.toLowerCase().contains(title)),
            )
            .toList();
        if (found.isNotEmpty) setState(() => found.first.done = true);
        if (found.isEmpty) {
          _lastMutationNotice = 'I could not find that open task. Nothing changed.';
        }
        _go('Tasks');
        break;
      case 'edit_record':
        _lastMutationNotice = _mutateRecord(f, delete: false);
        break;
      case 'delete_record':
        _lastMutationNotice = _mutateRecord(f, delete: true);
        break;
      default:
        break;
    }
    unawaited(_persistWindowsData());
  }

  String _confirmationPrompt(String phrase, _AssistantResult result) {
    if (result.action == 'read_screen' || _isReadRequest(phrase.toLowerCase())) {
      return 'I heard: $phrase. Would you like me to read this information?';
    }
    final proposal = result.reply.trim();
    return 'I heard: $phrase. ${proposal.isEmpty ? 'I am ready to continue.' : proposal}';
  }

  String _completedActionReply(_AssistantResult result) {
    if (_lastMutationNotice != null) return _lastMutationNotice!;
    final f = result.fields;
    switch (result.action) {
      case 'create_note':
        return 'Note created${f['title']?.isNotEmpty == true ? ': ${f['title']}' : ''}.';
      case 'create_task':
        return 'Task created${f['title']?.isNotEmpty == true ? ': ${f['title']}' : ''}.';
      case 'create_appointment':
        return 'Appointment added to the calendar.';
      case 'create_call':
        return 'Call note saved.';
      case 'create_enquiry':
        return 'Enquiry recorded.';
      case 'create_document':
        return 'Document draft created.';
      case 'create_email':
        return 'Email draft created. It has not been sent.';
      case 'visitor_checkin':
        return 'Visitor checked in.';
      case 'visitor_checkout':
        return 'Visitor checked out.';
      case 'complete_task':
        return 'Task marked complete.';
      case 'find_learner':
        return 'Learner search opened.';
      case 'read_screen':
      case 'answer':
        return result.reply;
      default:
        return result.reply;
    }
  }

  String _mutateRecord(Map<String, String> fields, {required bool delete}) {
    final type = fields['record_type']?.toLowerCase().trim() ?? '';
    final query = fields['query']?.toLowerCase().trim() ?? '';
    if (query.length < 2) return 'Please tell me which record you mean.';

    bool matches(Iterable<String> values) => values.any(
      (value) => value.toLowerCase().contains(query),
    );
    String value(String key, String old) =>
        fields[key]?.trim().isNotEmpty == true ? fields[key]!.trim() : old;
    DateTime? editedDate() {
      final raw = fields['dateTime']?.trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }
    bool didEdit = false;
    String? changed;

    switch (type) {
      case 'note':
      case 'notes':
        final indexes = [
          for (var i = 0; i < _notes.length; i++)
            if (matches([_notes[i].title, _notes[i].body])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('note', indexes.length);
        final i = indexes.single;
        final old = _notes[i];
        if (delete) {
          _notes.removeAt(i);
          changed = old.title;
        } else {
          final title = value('title', old.title);
          final body = value('body', old.body);
          didEdit = title != old.title || body != old.body;
          if (!didEdit) return 'Tell me what you would like changed in that note.';
          _notes[i] = _Note(title, body, old.when);
          changed = title;
        }
        _go('Notes');
        break;
      case 'task':
      case 'tasks':
        final indexes = [
          for (var i = 0; i < _tasks.length; i++)
            if (matches([_tasks[i].title, _tasks[i].detail])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('task', indexes.length);
        final i = indexes.single;
        final old = _tasks[i];
        if (delete) {
          _tasks.removeAt(i);
          changed = old.title;
        } else {
          final title = value('title', old.title);
          final detail = value('detail', old.detail);
          didEdit = title != old.title || detail != old.detail;
          if (!didEdit) return 'Tell me what you would like changed in that task.';
          _tasks[i] = _ReceptionTask(title, detail, old.created, old.done);
          changed = title;
        }
        _go('Tasks');
        break;
      case 'appointment':
      case 'appointments':
        final indexes = [
          for (var i = 0; i < _appointments.length; i++)
            if (matches([
              _appointments[i].title,
              _appointments[i].name,
              _appointments[i].category,
            ])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('appointment', indexes.length);
        final i = indexes.single;
        final old = _appointments[i];
        if (delete) {
          _appointments.removeAt(i);
          changed = old.title;
        } else {
          final title = value('title', old.title);
          final name = value('name', old.name);
          final date = editedDate();
          if (fields['dateTime']?.trim().isNotEmpty == true && date == null) {
            return 'I could not understand the new date and time.';
          }
          final location = value('location', old.location);
          final detail = value('detail', old.category);
          didEdit = title != old.title || name != old.name ||
              (date != null && date != old.when) || location != old.location ||
              detail != old.category;
          if (!didEdit) return 'Tell me what you would like changed in that appointment.';
          _appointments[i] = _Appointment(title, name, date ?? old.when, location, detail);
          changed = title;
        }
        _go('Calendar');
        break;
      case 'call':
      case 'calls':
        final indexes = [
          for (var i = 0; i < _calls.length; i++)
            if (matches([_calls[i].caller, _calls[i].reason, _calls[i].phone])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('call', indexes.length);
        final i = indexes.single;
        final old = _calls[i];
        if (delete) {
          _calls.removeAt(i);
          changed = old.caller;
        } else {
          final name = value('name', old.caller);
          final phone = value('phone', old.phone);
          final detail = value('detail', old.reason);
          final callback = fields.containsKey('callback')
              ? fields['callback']!.toLowerCase() == 'true'
              : old.callback;
          final priority = value('priority', old.priority);
          didEdit = name != old.caller || phone != old.phone || detail != old.reason ||
              callback != old.callback || priority != old.priority;
          if (!didEdit) return 'Tell me what you would like changed in that call record.';
          _calls[i] = _Call(name, phone, detail, callback, priority, old.when);
          changed = name;
        }
        _go('Call log');
        break;
      case 'enquiry':
      case 'enquiries':
        final indexes = [
          for (var i = 0; i < _enquiries.length; i++)
            if (matches([_enquiries[i].name, _enquiries[i].category, _enquiries[i].detail])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('enquiry', indexes.length);
        final i = indexes.single;
        final old = _enquiries[i];
        if (delete) {
          _enquiries.removeAt(i);
          changed = old.name;
        } else {
          final name = value('name', old.name);
          final category = value('category', old.category);
          final detail = value('detail', old.detail);
          final status = value('status', old.status);
          final priority = value('priority', old.priority);
          didEdit = name != old.name || category != old.category || detail != old.detail ||
              status != old.status || priority != old.priority;
          if (!didEdit) return 'Tell me what you would like changed in that enquiry.';
          _enquiries[i] = _Enquiry(name, category, detail, status, priority);
          changed = name;
        }
        _go('Enquiries');
        break;
      case 'document':
      case 'documents':
        final indexes = [
          for (var i = 0; i < _documents.length; i++)
            if (matches([_documents[i].title, _documents[i].summary])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('document', indexes.length);
        final i = indexes.single;
        final old = _documents[i];
        if (delete) {
          _documents.removeAt(i);
          changed = old.title;
        } else {
          final title = value('title', old.title);
          final detail = value('detail', old.summary);
          didEdit = title != old.title || detail != old.summary;
          if (!didEdit) return 'Tell me what you would like changed in that document.';
          _documents[i] = _Document(title, detail, old.when);
          changed = title;
        }
        _go('Documents');
        break;
      case 'email':
      case 'email draft':
      case 'emails':
        final indexes = [
          for (var i = 0; i < _emails.length; i++)
            if (matches([_emails[i].subject, _emails[i].recipient, _emails[i].body])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('email draft', indexes.length);
        final i = indexes.single;
        final old = _emails[i];
        if (delete) {
          _emails.removeAt(i);
          changed = old.subject;
        } else {
          final recipient = value('recipient', old.recipient);
          final subject = value('subject', old.subject);
          final body = value('body', old.body);
          didEdit = recipient != old.recipient || subject != old.subject || body != old.body;
          if (!didEdit) return 'Tell me what you would like changed in that email draft.';
          _emails[i] = _EmailDraft(recipient, subject, body, old.when);
          changed = subject;
        }
        _go('Emails');
        break;
      case 'visitor':
      case 'visitors':
        final indexes = [
          for (var i = 0; i < _visitors.length; i++)
            if (matches([_visitors[i].name, _visitors[i].host, _visitors[i].purpose])) i,
        ];
        if (indexes.length != 1) return _notUniqueNotice('visitor record', indexes.length);
        final i = indexes.single;
        final old = _visitors[i];
        if (delete) {
          _visitors.removeAt(i);
          changed = old.name;
        } else {
          final name = value('name', old.name);
          final host = value('host', old.host);
          final purpose = value('purpose', old.purpose);
          didEdit = name != old.name || host != old.host || purpose != old.purpose;
          if (!didEdit) return 'Tell me what you would like changed in that visitor record.';
          final replacement = _Visitor(name, host, purpose, old.checkedIn)
            ..checkedOut = old.checkedOut;
          _visitors[i] = replacement;
          changed = name;
        }
        _go('Visitors');
        break;
      default:
        return 'I could not identify the type of record to change.';
    }

    setState(() {});
    unawaited(_persistWindowsData());
    return delete
        ? 'Deleted $changed.'
        : 'Updated $changed.';
  }

  String _notUniqueNotice(String type, int count) => switch (count) {
    0 => 'I could not find that $type. Nothing was changed.',
    _ => 'I found more than one matching $type. Please say its exact name or title.',
  };

  Future<void> _askCopilot(String question) async {
    if (_assistantBusy || question.trim().isEmpty) return;
    if (_isWindowsDesktop) {
      try {
        await _offlineDataReady.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    final resumeVoice = _voiceSession;
    if (resumeVoice) {
      _audioCheckTimer?.cancel();
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _speech.stop();
      _listening = false;
    }
    _chat.add(_ChatLine(true, question));
    setState(() => _assistantBusy = true);
    _refreshAssistantPopup();
    final result = await _askModel(question);
    String answer;
    if (result != null) {
      if (_requiresAssistantConfirmation(result.action, question.toLowerCase())) {
        final approved = await _confirmByKey(
          _confirmationPrompt(question, result),
        );
        if (approved) {
          _lastMutationNotice = null;
          _applyAssistantAction(result);
          answer = _lastMutationNotice ?? 'Done. ${result.reply}';
        } else {
          answer = 'Okay. I did not make that change.';
        }
      } else {
        _applyAssistantAction(result);
        answer = result.action == 'navigate'
            ? 'Opening ${result.destination}.'
            : result.reply;
      }
    } else {
      final approved = !_requiresLocalConfirmation(question.toLowerCase()) ||
          await _confirmByKey(
            'This request will read or change information. Do you want me to continue?',
          );
      if (approved) {
        await _handleVoiceCommand(
          question,
          consultAi: false,
          resumeVoice: false,
          speakResponse: false,
          skipLocalConfirmation: true,
        );
        final transcript = _transcript.split('\n');
        answer =
            'Online AI is temporarily unavailable. I used the built-in command helper instead. ${transcript.length > 1 ? transcript.skip(1).join(' ') : _answerLocally(question)}';
      } else {
        answer = 'Okay. I did not make that change.';
      }
    }
    _chat.add(_ChatLine(false, answer));
    if (mounted) setState(() => _assistantBusy = false);
    _refreshAssistantPopup();
    await _speak(answer);
    await _waitForSpeechToFinish();
    if (resumeVoice && _voiceSession && mounted) {
      await _stopVoiceAfterTask();
    }
  }

  Future<bool> _confirmByKey(String details, {bool speakPrompt = true}) async => true;

  Future<void> _toggleVoice({bool greet = false}) async {
    if (_voiceSession || _listening) {
      _voiceSession = false;
      _processing = false;
      _awaitingSessionChoice = false;
      _listenRestartTimer?.cancel();
      _audioCheckTimer?.cancel();
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _speech.stop();
      _stopSpeaking();
      if (mounted)
        setState(() {
          _listening = false;
          _transcript = 'Voice session ended.';
        });
      _refreshAssistantPopup();
      return;
    }
    _preferOnDeviceSpeech = true;
    _forceOfflineSpeech = false;
    _awaitingSessionChoice = false;
    _listenFailures = 0;
    if (_isWindowsDesktop) {
      try {
        await _offlineDataReady.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        _assistantError =
            'Microphone access is blocked. Allow it in Windows or browser settings.';
      }
    } catch (_) {
      // The system speech service may still be available as the fallback.
    }
    _speechReady = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        final message = error.errorMsg.toLowerCase();
        final permissionDenied =
            message.contains('permission') ||
            message.contains('denied') ||
            message.contains('not-allowed');
        if (!_isWindowsDesktop && !permissionDenied && _preferOnDeviceSpeech) {
          _preferOnDeviceSpeech = false;
          _listenFailures = 0;
          _assistantError = 'No offline speech pack was found for this language. Trying the device speech service.';
          _refreshAssistantPopup();
          _scheduleListenRestart();
          return;
        }
        _listenFailures++;
        final stoppedAfterRetries = _listenFailures >= 3;
        setState(() {
          _listening = false;
          if (permissionDenied || stoppedAfterRetries) _voiceSession = false;
          _assistantError = permissionDenied
              ? 'Microphone access is blocked. Allow microphone access in your browser or device settings.'
              : stoppedAfterRetries
              ? _isWindowsDesktop
                    ? 'Windows offline speech recognition could not start. Check Windows speech settings and microphone access.'
                    : 'Speech recognition could not start. Check the microphone and the device speech service.'
              : 'Speech recognition stopped; Liyabona is trying to restart it.';
          _transcript = permissionDenied
              ? 'Microphone access is blocked. Allow microphone access in your browser or device settings.'
              : 'Speech recognition stopped. Retrying…';
        });
        _refreshAssistantPopup();
        if (!permissionDenied && !stoppedAfterRetries) _scheduleListenRestart();
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'listening') {
          _listenFailures = 0;
          _listenRestartTimer?.cancel();
          setState(() => _listening = true);
          _refreshAssistantPopup();
        } else if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
          _refreshAssistantPopup();
          _scheduleListenRestart();
        }
      },
    );
    if (!_speechReady) {
      _speechLocale = null;
      _assistantError =
          'Built-in speech recognition is unavailable; online voice recognition will still be tried.';
    } else {
      _assistantError = '';
      try {
        final supported = await _speech.locales();
        final localeById = {
          for (final locale in supported)
            locale.localeId.replaceAll('_', '-'): locale,
        };
        _speechLocale = const [
          'en-ZA',
          'en-GB',
          'en-AU',
          'en-CA',
          'en-IN',
          'en-US',
        ].firstWhere(localeById.containsKey, orElse: () => '');
        if (_speechLocale!.isEmpty) _speechLocale = null;
        if (_isWindowsDesktop && _speechLocale != 'en-ZA') {
          final selectedLocale = _speechLocale;
          final selectedName = selectedLocale == null
              ? 'Windows default English'
              : localeById[selectedLocale]!.name;
          _assistantError =
              'Online transcription is set to South African English. The offline fallback will use $selectedName.';
        }
      } catch (_) {
        _speechLocale = null;
      }
    }
    setState(() {
      _voiceSession = true;
      _transcript = 'Ready for your voice.';
    });
    _refreshAssistantPopup();
    if (greet) {
      // Start speech recognition inside the tap gesture. Some browsers reject
      // microphone startup if it is delayed until after the spoken greeting.
      _greetingPlaying = true;
      await _listenOnce();
      await _speak('Hello, I hope you are doing well');
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      _greetingPlaying = false;
      if (_voiceSession && !_listening) await _listenOnce();
      return;
    }
    await _listenOnce();
  }

  Future<void> _listenOnce() async {
    if (!_voiceSession || !mounted || _processing || _listening) return;
    if (_forceOfflineSpeech) {
      await _listenOfflineOnce();
      return;
    }
    _listenRestartTimer?.cancel();
    _wakeWordRestartTimer?.cancel();
    try {
      if (!await _audioRecorder.hasPermission()) {
        throw StateError('Microphone permission was not granted.');
      }
      _audioBuffer = BytesBuilder(copy: false);
      _audioStartedAt = DateTime.now();
      _lastVoicedAt = null;
      _voicedSampleCount = 0;
      _finishingAudio = false;
      _recordingSampleRate = 16000;
      _recordingChannels = 1;
      await _audioRecorder.setOnConfigChanged((config) {
        _recordingSampleRate = config.sampleRate;
        _recordingChannels = config.numChannels;
      });
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _audioSubscription = stream.listen(
        _collectAudio,
        onError: (_) => unawaited(_useOfflineSpeech()),
        cancelOnError: true,
      );
      if (mounted) {
        setState(() {
          _listening = true;
          _transcript = 'Listening for your voice…';
          _assistantError = '';
        });
      }
      _refreshAssistantPopup();
      _audioCheckTimer?.cancel();
      _audioCheckTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (!_voiceSession || !mounted || _finishingAudio) return;
        final now = DateTime.now();
        if (_greetingPlaying) {
          _audioBuffer = BytesBuilder(copy: false);
          _voicedSampleCount = 0;
          _lastVoicedAt = null;
          _audioStartedAt = now;
          return;
        }
        final startedAt = _audioStartedAt ?? now;
        final lastVoicedAt = _lastVoicedAt;
        if (lastVoicedAt != null &&
            now.difference(lastVoicedAt) >= const Duration(milliseconds: 900)) {
          unawaited(_finishAudioCapture());
        } else if (lastVoicedAt == null &&
            now.difference(startedAt) >= const Duration(seconds: 8)) {
          unawaited(_finishAudioCapture(noSpeech: true));
        } else if (now.difference(startedAt) >= const Duration(seconds: 15)) {
          unawaited(_finishAudioCapture());
        }
      });
    } catch (_) {
      await _useOfflineSpeech();
    }
  }

  void _collectAudio(Uint8List chunk) {
    if (_greetingPlaying || chunk.length < 2 || _finishingAudio) return;
    _audioBuffer.add(chunk);
    var sumSquares = 0.0;
    var count = 0;
    final data = ByteData.sublistView(chunk);
    for (var offset = 0; offset + 1 < chunk.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little) / 32768.0;
      sumSquares += sample * sample;
      count++;
    }
    if (count == 0) return;
    final rms = sqrt(sumSquares / count);
    // Ignore room tone and light handling noise. A few hundred milliseconds
    // of sustained voice energy are required before any audio is sent online.
    if (rms >= 0.008) {
      _voicedSampleCount += count;
      _lastVoicedAt = DateTime.now();
    }
  }

  Future<void> _finishAudioCapture({bool noSpeech = false}) async {
    if (_finishingAudio) return;
    _finishingAudio = true;
    _audioCheckTimer?.cancel();
    _audioCheckTimer = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (!_voiceSession || !mounted) {
      _finishingAudio = false;
      return;
    }
    if (noSpeech || _voicedSampleCount < 2400) {
      _finishingAudio = false;
      setState(() {
        _listening = false;
        _transcript = 'Repeat again.';
      });
      _refreshAssistantPopup();
      await _speak('Repeat again.');
      _scheduleListenRestart();
      return;
    }

    final pcm = _audioBuffer.takeBytes();
    final wav = _wrapPcmAsWav(pcm);
    setState(() {
      _listening = false;
      _processing = true;
      _transcript = 'Transcribing your request…';
    });
    _refreshAssistantPopup();
    final result = await _askModel(
      '',
      audioBase64: base64Encode(wav),
    );
    _finishingAudio = false;
    if (!_voiceSession || !mounted) return;
    if (result == null) {
      await _useOfflineSpeech();
      return;
    }
    final cleaned = result.transcript.trim();
    const transcriptConfidenceFloor = 0.72;
    if (cleaned.length < 2 || result.confidence < transcriptConfidenceFloor) {
      if (!_forceOfflineSpeech && _speechReady) {
        await _useOfflineSpeech();
        return;
      }
      _processing = false;
      setState(() {
        _transcript = 'Repeat again.';
      });
      _refreshAssistantPopup();
      await _speak('Repeat again.');
      _scheduleListenRestart();
      return;
    }
    _forceOfflineSpeech = false;
    setState(() => _transcript = 'I heard: $cleaned');
    _refreshAssistantPopup();
    await _handleVoiceCommand(
      cleaned,
      assistantResultOverride: result,
    );
  }

  Uint8List _wrapPcmAsWav(Uint8List pcm) {
    final wav = Uint8List(44 + pcm.length);
    final header = ByteData.sublistView(wav);
    void fourCc(int offset, String value) {
      wav.setRange(offset, offset + 4, ascii.encode(value));
    }

    fourCc(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    fourCc(8, 'WAVE');
    fourCc(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, _recordingChannels, Endian.little);
    header.setUint32(24, _recordingSampleRate, Endian.little);
    header.setUint32(
      28,
      _recordingSampleRate * _recordingChannels * 2,
      Endian.little,
    );
    header.setUint16(32, _recordingChannels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    fourCc(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    wav.setRange(44, wav.length, pcm);
    return wav;
  }

  Future<void> _useOfflineSpeech() async {
    if (!_voiceSession || !mounted) return;
    _audioCheckTimer?.cancel();
    _audioCheckTimer = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _finishingAudio = false;
    if (!_speechReady) {
      _voiceSession = false;
      _processing = false;
      _listening = false;
      _transcript = 'Repeat again.';
      _refreshAssistantPopup();
      await _speak('Repeat again.');
      return;
    }
    _forceOfflineSpeech = true;
    _processing = false;
    _assistantError =
        'Online speech recognition is unavailable. Using this device’s built-in speech recognition.';
    _refreshAssistantPopup();
    await _listenOfflineOnce();
  }

  Future<void> _listenOfflineOnce() async {
    if (!_voiceSession || !mounted || _processing || _listening) return;
    _listenRestartTimer?.cancel();
    setState(() => _listening = true);
    _refreshAssistantPopup();
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _speechLocale,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 3),
          partialResults: !_isWindowsDesktop,
          cancelOnError: false,
          onDevice: _isWindowsDesktop || _preferOnDeviceSpeech,
        ),
        onResult: (result) {
          if (!mounted) return;
          final heard = result.recognizedWords.trim();
          if (heard.isEmpty) return;
          _listenFailures = 0;
          if (_greetingPlaying) return;
          if (_ttsSpeaking && _isSpeechInterruption(heard)) {
            _stopSpeaking();
          } else if (_ttsSpeaking && _soundsLikeCurrentSpeech(heard)) {
            return;
          }
          setState(() => _transcript = heard);
          if (result.finalResult && !_processing) {
            _processing = true;
            if (_ttsSpeaking) _stopSpeaking();
            _refreshAssistantPopup();
            unawaited(
              _handleVoiceCommand(heard, consultAi: !_forceOfflineSpeech),
            );
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _transcript =
            'Could not start speech recognition. Check microphone access.';
        _listenFailures++;
        if (_listenFailures >= 3) {
          _voiceSession = false;
          _assistantError = _transcript;
        } else {
          _assistantError =
              'Speech recognition stopped; Liyabona is trying to restart it.';
        }
      });
      _refreshAssistantPopup();
      if (_voiceSession) _scheduleListenRestart();
    }
  }

  void _scheduleListenRestart() {
    _listenRestartTimer?.cancel();
    if (!_voiceSession || _processing || _greetingPlaying || !mounted) return;
    _listenRestartTimer = Timer(const Duration(milliseconds: 650), () {
      if (_voiceSession && !_processing && !_listening && mounted) {
        unawaited(_listenOnce());
      }
    });
  }

  bool _isSpeechInterruption(String phrase) {
    final command = phrase.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ');
    return RegExp(r'\b(stop|quiet|be quiet|cancel|hold on|wait)\b')
        .hasMatch(command);
  }

  bool _soundsLikeCurrentSpeech(String phrase) {
    String clean(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final heard = clean(phrase);
    final spoken = clean(_lastSpeechText);
    if (heard.length < 8 || spoken.isEmpty) return false;
    if (spoken.contains(heard) || heard.contains(spoken)) return true;
    final words = heard.split(' ').where((word) => word.length > 2).toSet();
    if (words.isEmpty) return false;
    final shared = words.where(spoken.split(' ').toSet().contains).length;
    return shared / words.length > .72;
  }

  void _announce(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _handleVoiceCommand(
    String phrase, {
    bool consultAi = true,
    bool resumeVoice = true,
    bool speakResponse = true,
    bool skipLocalConfirmation = false,
    _AssistantResult? assistantResultOverride,
  }) async {
    final command = phrase.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final stopCommand =
        command.contains('stop listening') ||
        command.contains('stop voice') ||
        command.contains('close voice session') ||
        command.contains('close assistant');
    final stopSpeechOnly = RegExp(
      r'^(stop|stop speaking|stop talking|be quiet|quiet|cancel|hold on|wait)[.! ]*$',
    ).hasMatch(command);
    if (stopCommand || stopSpeechOnly) {
      await _speech.stop();
      _stopSpeaking();
      if (stopCommand) {
        _voiceSession = false;
        _awaitingSessionChoice = false;
      }
      _processing = false;
      if (mounted) {
        setState(() {
          _listening = false;
          _transcript = stopCommand ? 'Voice assistant stopped.' : 'Okay.';
        });
      }
      _refreshAssistantPopup();
      if (stopCommand) await _speak('Okay, I have stopped listening.');
      if (!stopCommand && resumeVoice && _voiceSession && mounted) {
        await _listenOnce();
      }
      return;
    }
    if (_isWindowsDesktop && _isWindowsScreenReadCommand(command)) {
      _heardPhrase = phrase;
      _interpretation = 'Reading text from the active app';
      _chat.add(_ChatLine(true, phrase));
      await _readActiveWindowsScreen();
      return;
    }
    if (_isWindowsDesktop && _isContinueScreenReadCommand(command)) {
      _heardPhrase = phrase;
      _interpretation = 'Continuing to read the active app';
      await _readActiveWindowsScreen(continueReading: true);
      return;
    }
    if (_isWindowsDesktop && _isRepeatScreenReadCommand(command)) {
      _heardPhrase = phrase;
      _interpretation = 'Repeating the last screen section';
      await _readActiveWindowsScreen(repeatLast: true);
      return;
    }
    var response = 'Repeat again.';
    _heardPhrase = phrase;
    _interpretation = 'Checking your request with Liyabona AI';
    _matchConfidence = null;
    if (consultAi) {
      await _speech.stop();
      _listening = false;
      final result = assistantResultOverride ?? await _askModel(phrase);
      if (_isWindowsDesktop && result?.action == 'read_screen') {
        _heardPhrase = phrase;
        _interpretation = 'Reading text from the active app';
        _chat.add(_ChatLine(true, phrase));
        await _readActiveWindowsScreen();
        return;
      }
      if (result != null &&
          _requiresAssistantConfirmation(result.action, command)) {
        final confirmation = _confirmationPrompt(phrase, result);
        _chat.add(_ChatLine(true, phrase));
        _chat.add(_ChatLine(false, confirmation));
        if (mounted) {
          setState(() {
            _transcript = '“$phrase”\n$confirmation';
            _listening = false;
          });
        }
        _refreshAssistantPopup();
        final approved = await _confirmByKey(
          confirmation,
          speakPrompt: speakResponse,
        );
        String actionReply;
        if (approved) {
          _lastMutationNotice = null;
          _applyAssistantAction(result);
          actionReply = _completedActionReply(result);
        } else {
          actionReply = 'No key was pressed. I cancelled, and nothing changed.';
        }
        _chat.add(_ChatLine(false, actionReply));
        if (mounted) setState(() => _transcript = '“$phrase”\n$actionReply');
        _refreshAssistantPopup();
        if (speakResponse) await _speak(actionReply);
        await _waitForSpeechToFinish();
        _processing = false;
        if (resumeVoice && _voiceSession && mounted) {
          await _stopVoiceAfterTask();
        }
        return;
      }
      if (result != null &&
          result.action != 'answer' &&
          result.action != 'clarify') {
        _applyAssistantAction(result);
        final actionReply = result.action == 'navigate'
            ? 'Opening ${result.destination}.'
            : result.reply;
        _chat.add(_ChatLine(true, phrase));
        _chat.add(_ChatLine(false, actionReply));
        _pendingChoices = [];
        _interpretation = result.action == 'navigate'
            ? 'Opening ${result.destination}'
            : result.action == 'clarify'
            ? 'AI needs one more detail'
            : 'AI action: ${result.action.replaceAll('_', ' ')}';
        _matchConfidence = null;
        if (mounted) {
          setState(() {
            _transcript = '“$phrase”\n$actionReply';
            _listening = false;
          });
        }
        _refreshAssistantPopup();
        if (speakResponse) await _speak(actionReply);
        _processing = false;
        _refreshAssistantPopup();
        if (resumeVoice && _voiceSession && mounted) {
          await _stopVoiceAfterTask();
        }
        return;
      }
      if (result != null && result.action == 'clarify') {
        _chat.add(_ChatLine(true, phrase));
        _chat.add(_ChatLine(false, result!.reply));
        _interpretation = 'Liyabona needs one more detail';
        if (mounted) {
          setState(() {
            _transcript = '“$phrase”\n${result.reply}';
            _listening = false;
          });
        }
        _refreshAssistantPopup();
        if (speakResponse) await _speak(result.reply);
        _processing = false;
        if (resumeVoice && _voiceSession && mounted) {
          await _stopVoiceAfterTask();
        }
        return;
      }
      if (result != null) {
        // The AI heard the request but could not turn it into an app action.
        // Give the built-in command handler the same recognized words before
        // falling back to the AI's spoken answer or clarification.
        if (_requiresLocalConfirmation(command)) {
          const confirmation =
              'This request will read or change information.';
          _chat.add(_ChatLine(true, phrase));
          _chat.add(_ChatLine(false, confirmation));
          if (mounted) setState(() => _transcript = '“$phrase”\n$confirmation');
          _refreshAssistantPopup();
          final approved = await _confirmByKey(
            confirmation,
            speakPrompt: speakResponse,
          );
          if (approved) {
            await _handleVoiceCommand(
              phrase,
              consultAi: false,
              resumeVoice: false,
              speakResponse: false,
              skipLocalConfirmation: true,
            );
            final lines = _transcript.split('\n');
            response = lines.length > 1 ? lines.skip(1).join(' ') : 'Done.';
          } else {
            response = 'No key was pressed. I cancelled, and nothing changed.';
          }
          _chat.add(_ChatLine(false, response));
          if (mounted) setState(() => _transcript = '“$phrase”\n$response');
          _refreshAssistantPopup();
          if (speakResponse) await _speak(response);
          _processing = false;
          if (resumeVoice && _voiceSession && mounted) {
            await _stopVoiceAfterTask();
          }
          return;
        }
        await _handleVoiceCommand(
          phrase,
          consultAi: false,
          resumeVoice: false,
          speakResponse: false,
        );
        final localTranscript = _transcript.split('\n');
        final localReply = localTranscript.length > 1
            ? localTranscript.skip(1).join(' ')
            : '';
        final localHandled =
            localReply.isNotEmpty &&
            !localReply.startsWith('I heard $phrase. Say help');
        final answer = localHandled ? localReply : result.reply;
        _chat.add(_ChatLine(true, phrase));
        _chat.add(_ChatLine(false, answer));
        _interpretation = localHandled
            ? 'Completed using the built-in command helper'
            : 'Liyabona AI answered your request';
        if (mounted) {
          setState(() {
            _transcript = '“$phrase”\n$answer';
            _listening = false;
          });
        }
        _refreshAssistantPopup();
        if (speakResponse) await _speak(answer);
        _processing = false;
        _refreshAssistantPopup();
        if (resumeVoice && _voiceSession && mounted) {
          await _stopVoiceAfterTask();
        }
        return;
      }
    }
    if (!skipLocalConfirmation && _requiresLocalConfirmation(command)) {
      const confirmation =
          'This request will read or change information.';
      _chat.add(_ChatLine(true, phrase));
      _chat.add(_ChatLine(false, confirmation));
      if (mounted) setState(() => _transcript = '“$phrase”\n$confirmation');
      _refreshAssistantPopup();
      final approved = await _confirmByKey(
        confirmation,
        speakPrompt: speakResponse,
      );
      if (approved) {
        await _handleVoiceCommand(
          phrase,
          consultAi: false,
          resumeVoice: false,
          speakResponse: false,
          skipLocalConfirmation: true,
        );
        final lines = _transcript.split('\n');
        response = lines.length > 1 ? lines.skip(1).join(' ') : 'Done.';
      } else {
        response = 'No key was pressed. I cancelled, and nothing changed.';
      }
      _chat.add(_ChatLine(false, response));
      if (mounted) setState(() => _transcript = '“$phrase”\n$response');
      _refreshAssistantPopup();
      if (speakResponse) await _speak(response);
      _processing = false;
      if (resumeVoice && _voiceSession && mounted) {
        await _stopVoiceAfterTask();
      }
      return;
    }
    _heardPhrase = phrase;
    _interpretation = 'Checking your request against this app';
    _matchConfidence = null;
    if (_pendingChoices.isNotEmpty) {
      final selection = _choosePending(command);
      if (selection == null) {
        response =
            'I am not sure which one you mean. Please say ${_pendingChoices.join(' or ')}.';
        _interpretation = 'Need a clearer choice';
        _matchConfidence = .35;
      } else {
        _go(selection);
        _pendingChoices = [];
        _interpretation = 'Opening $selection';
        _matchConfidence = .99;
        response = 'Okay, opening $selection.';
      }
    } else if (command.contains('stop listening') ||
        command.contains('stop voice') ||
        command.contains('close voice session')) {
      _voiceSession = false;
      _listening = false;
      response = 'Voice session ended.';
    } else if (command.contains('help') ||
        command.contains('what can you do')) {
      response = 'You can ask me to open a screen, create a note or task, edit a saved record, draft an email, organise a visitor check-in, or say read to hear text from the active app. Say continue reading for the next section or repeat to hear the last section again. I stop listening after each request.';
    } else if (command.contains('read this screen') ||
        command.contains('summarise this screen') ||
        command.contains('summarize this screen') ||
        command == 'read screen') {
      response = _pageSummary();
    } else if (_isNavigationRequest(command)) {
      final match = _interpretDestination(command);
      if (match.choices.length > 1) {
        _pendingChoices = match.choices;
        _interpretation = 'Possible screens: ${match.choices.join(' or ')}';
        _matchConfidence = match.confidence;
        response =
            'I heard “$phrase”. Did you mean ${match.choices[0]} or ${match.choices[1]}?';
      } else if (match.choices.isNotEmpty) {
        final destination = match.choices.first;
        _go(destination);
        _interpretation = 'Opening $destination';
        _matchConfidence = match.confidence;
        response =
            'I understood that as $destination. Opening it now.';
      } else {
        _interpretation = 'I could not match that to a screen';
        _matchConfidence = .2;
        response =
            'I heard “$phrase”, but I could not match it to a screen. Say help to hear available screens.';
      }
    } else if (RegExp(
      r'^(?:delete|remove)\s+(?:the\s+)?(email draft|appointments?|notes?|tasks?|calls?|enquiries?|documents?|emails?|visitors?)\s+(.+)$',
    ).hasMatch(command)) {
      final match = RegExp(
        r'^(?:delete|remove)\s+(?:the\s+)?(email draft|appointments?|notes?|tasks?|calls?|enquiries?|documents?|emails?|visitors?)\s+(.+)$',
      ).firstMatch(command)!;
      final target = match.group(2)!.replaceFirst(
        RegExp(r'^(?:called|named|about)\s+'),
        '',
      );
      response = _lastMutationNotice = _mutateRecord(
        {'record_type': match.group(1)!, 'query': target},
        delete: true,
      );
    } else if (RegExp(
      r'^(?:edit|update|change)\s+(?:the\s+)?(email draft|appointments?|notes?|tasks?|calls?|enquiries?|documents?|emails?|visitors?)\s+(.+?)\s+(title|body|detail|name|date time|location|phone|priority|status|category|recipient|subject|host|purpose)\s+to\s+(.+)$',
    ).hasMatch(command)) {
      final match = RegExp(
        r'^(?:edit|update|change)\s+(?:the\s+)?(email draft|appointments?|notes?|tasks?|calls?|enquiries?|documents?|emails?|visitors?)\s+(.+?)\s+(title|body|detail|name|date time|location|phone|priority|status|category|recipient|subject|host|purpose)\s+to\s+(.+)$',
      ).firstMatch(command)!;
      final field = match.group(3) == 'date time'
          ? 'dateTime'
          : match.group(3)!.replaceAll(' ', '');
      response = _lastMutationNotice = _mutateRecord({
        'record_type': match.group(1)!,
        'query': match.group(2)!,
        field: _cleanStart(match.group(4)!),
      }, delete: false);
    } else if (command.startsWith('check out ') ||
        command.startsWith('sign out visitor')) {
      final person = _stripIntent(command, [
        'check out visitor',
        'check out',
        'sign out visitor',
      ]);
      final matches = _visitors
          .where(
            (v) =>
                v.checkedOut == null &&
                (person.isEmpty || v.name.toLowerCase().contains(person)),
          )
          .toList();
      final visitor = matches.isEmpty ? null : matches.first;
      if (visitor == null) {
        response = 'I could not find a checked-in visitor with that name.';
      } else {
        visitor.checkedOut = DateTime.now();
        _go('Visitors');
        response = 'I checked out ${visitor.name}.';
      }
    } else if (command.contains('visitor') &&
        (_hasCreateIntent(command) ||
            command.contains('check in') ||
            command.contains('sign in') ||
            command.contains('register'))) {
      final details = _stripIntent(command, [
        'check in visitor',
        'check in',
        'sign in visitor',
        'sign in',
        'register visitor',
        'add visitor',
        'new visitor',
      ]);
      final name = details
          .split(RegExp(r'\b(visiting|to see|about)\b'))
          .first
          .trim();
      final host = _after(details, ['visiting ', 'to see ']);
      final visitor = _Visitor(
        name.isEmpty ? 'Walk-in visitor' : _titleCase(name),
        host.isEmpty ? 'Student Support' : _titleCase(host),
        'Campus visit',
        DateTime.now(),
      );
      _visitors.insert(0, visitor);
      _go('Visitors');
      response =
          'I checked in ${visitor.name}${host.isEmpty ? '' : ' to visit ${visitor.host}'}. Remember to check them out when they leave.';
    } else if (command.startsWith('remind me') ||
        command.startsWith('set a reminder') ||
        command.startsWith('create reminder') ||
        (command.contains('reminder') && _hasCreateIntent(command))) {
      final detail = _stripIntent(command, [
        'remind me to',
        'remind me',
        'set a reminder to',
        'set a reminder',
        'create reminder to',
        'create reminder',
      ]);
      final task = _ReceptionTask(
        detail.isEmpty ? 'New reminder' : _titleCase(detail),
        detail.isEmpty ? 'Reminder details to be added.' : detail,
        DateTime.now(),
        false,
      );
      _tasks.insert(0, task);
      _go('Tasks');
      response = detail.isEmpty
          ? 'I added a blank reminder to your task list.'
          : 'I saved a reminder in your task list: ${task.title}.';
    } else if (command.contains('task') && _hasCreateIntent(command)) {
      final detail = _stripIntent(command, [
        'create a task',
        'create task',
        'add a task',
        'add task',
        'make a task',
        'new task',
        'remind me to',
      ]);
      final task = _ReceptionTask(
        detail.isEmpty ? 'New reception task' : _titleCase(detail),
        detail.isEmpty ? 'Details to be added.' : detail,
        DateTime.now(),
        false,
      );
      _tasks.insert(0, task);
      _go('Tasks');
      response = 'I added the task: ${task.title}.';
    } else if (command.startsWith('complete task') ||
        command.startsWith('finish task')) {
      final title = _stripIntent(command, ['complete task', 'finish task']);
      final matches = _tasks
          .where(
            (task) =>
                !task.done &&
                (title.isEmpty || task.title.toLowerCase().contains(title)),
          )
          .toList();
      if (matches.isEmpty) {
        response = 'I could not find an open task with that name.';
      } else {
        matches.first.done = true;
        _go('Tasks');
        response = 'I marked ${matches.first.title} as complete.';
      }
    } else if (command.contains('task') || command.contains('reminder')) {
      _go('Tasks');
      final open = _tasks.where((task) => !task.done).toList();
      response = open.isEmpty
          ? 'There are no open tasks or reminders.'
          : 'You have ${open.length} open tasks. ${open.take(5).map((task) => task.title).join('. ')}';
    } else if (command.contains('calendar') ||
        command.contains('appointments') ||
        command.contains('appointment') ||
        command.contains('schedule')) {
      _go('Calendar');
      response = _calendarSummary();
      if (_hasCreateIntent(command)) {
        final person = _after(command, ['with ', 'for ']);
        final name = person.isEmpty
            ? 'Walk-in learner'
            : _titleCase(
                person
                    .split(RegExp(r'\b(on|at|about|today|tomorrow)\b'))
                    .first
                    .trim(),
              );
        final purpose = _after(command, ['about ', 'for ']);
        {
          final at = _parseAppointmentDate(command);
          _appointments.insert(
            0,
            _Appointment(
              purpose.isEmpty ? 'Reception follow-up' : _titleCase(purpose),
              name,
              DateTime(at.year, at.month, at.day, 10),
              'Student Support office',
              purpose.isEmpty ? 'Follow-up' : purpose,
            ),
          );
          response =
              'I scheduled ${purpose.isEmpty ? 'a follow-up' : purpose} with $name for ${_spokenDateTime(at)}. ' +
              _calendarSummary();
        }
      }
    } else if (command.contains('call-back') ||
        command.contains('callback') ||
        command.contains('call back')) {
      _go('Call log');
      final due = _calls.where((call) => call.callback).length;
      response =
          'There are $due call-backs waiting. ' +
          _calls
              .where((call) => call.callback)
              .map((call) => '${call.caller}: ${call.reason}')
              .join('. ');
    } else if (command.contains('call') && _hasCreateIntent(command)) {
      final details = _stripIntent(command, [
        'log a call',
        'record a call',
        'make a call note',
        'new call',
      ]);
      final callerMatch = RegExp(
        r'^(?:from|caller)\s+(.+?)(?:\s+(?:about|saying|that)\s+(.+))?$',
      ).firstMatch(details);
      final caller = callerMatch == null
          ? 'Voice caller'
          : _titleCase(callerMatch.group(1)!.trim());
      final reason = callerMatch?.group(2)?.trim() ?? details;
      _calls.insert(
        0,
        _Call(
          caller,
          '',
          reason.isEmpty ? 'Details captured by reception.' : reason,
          true,
          'Normal',
          DateTime.now(),
        ),
      );
      _go('Call log');
      response =
          'I logged the call from $caller and added it to the call-back list. ${_calls.first.reason}';
    } else if ((command.contains('note') || command.contains('remind')) &&
        _hasCreateIntent(command) &&
        !command.startsWith('add to my note') &&
        !command.startsWith('append to my note')) {
      final content = _stripIntent(command, [
        'create a note',
        'make a note',
        'take a note',
        'new note',
        'write a note',
        'note that',
        'remind me to',
      ]);
      final noteText = content.isEmpty
          ? 'New voice note. Details to be added.'
          : _cleanStart(content);
      _notes.insert(0, _Note('Voice note', noteText, DateTime.now()));
      _go('Notes');
      response = content.isEmpty
          ? 'I created a blank voice note. You can now say, add to my note, followed by the details.'
          : 'I saved a voice note: $noteText';
    } else if (command.startsWith('add to my note') ||
        command.startsWith('append to my note')) {
      final addition = _stripIntent(command, [
        'add to my note',
        'append to my note',
      ]);
      if (_notes.isEmpty) {
        _notes.insert(0, _Note('Voice note', addition, DateTime.now()));
      } else {
        final previous = _notes.first;
        _notes[0] = _Note(
          previous.title,
          '${previous.body} ${_cleanStart(addition)}',
          previous.when,
        );
      }
      _go('Notes');
      response = 'I added that to your latest note.';
    } else if ((command.contains('document') ||
            command.contains('letter') ||
            command.contains('pdf')) &&
        _hasCreateIntent(command)) {
      final topic = _stripIntent(command, [
        'create a document',
        'make a document',
        'draft a letter',
        'generate a document',
        'create a pdf',
      ]);
      final title = topic.isEmpty
          ? 'Reception document'
          : 'Document about ${_titleCase(topic)}';
      _documents.insert(
        0,
        _Document(title, 'Draft prepared in Liyabona.', DateTime.now()),
      );
      _go('Documents');
      response =
          'I created a draft called $title. Open Documents to review and print it.';
    } else if (command.contains('email') && _hasCreateIntent(command)) {
      final rawRecipient = _after(command, [
        'email to ',
        'message to ',
        ' to ',
      ]);
      final recipient = rawRecipient
          .split(RegExp(r'\b(about|regarding|with subject)\b'))
          .first
          .trim();
      final topic = _after(command, ['about ', 'regarding ', 'with subject ']);
      final subject = topic.isEmpty
          ? 'Student Support follow-up'
          : _titleCase(topic);
      final salutation = recipient.isEmpty ? 'there' : _titleCase(recipient);
      final body =
          'Dear $salutation,\n\nI am writing regarding ${topic.isEmpty ? 'your recent enquiry' : topic}. Please let me know if you need any further assistance.\n\nKind regards,\nStudent Support Reception';
      _emails.insert(
        0,
        _EmailDraft(
          recipient.isEmpty ? 'Recipient to be confirmed' : recipient,
          subject,
          body,
          DateTime.now(),
        ),
      );
      _go('Emails');
      response =
          'I drafted an email to ${recipient.isEmpty ? 'review' : recipient} with the subject $subject. It has not been sent.';
    } else if (command.contains('email') || command.contains('draft')) {
      _go('Emails');
      response = _summaryFor('Emails');
    } else if (command.contains('learner') ||
        command.contains('student') ||
        command.contains('directory')) {
      _go('Learners');
      final person = _after(command, ['find ', 'search for ', 'look up ']);
      if (person.isNotEmpty) _search = person;
      response = 'I opened the learner directory. The listed contacts are illustrative; college-approved records can be added after access is arranged.';
    } else if (command.contains('enquir') ||
        command.contains('request') ||
        command.contains('case')) {
      _go('Enquiries');
      if (_hasCreateIntent(command)) {
        final detail = _stripIntent(command, [
          'create an enquiry',
          'new enquiry',
          'log an enquiry',
          'record an enquiry',
        ]);
        _enquiries.insert(
          0,
          _Enquiry(
            'Walk-in learner',
            'General enquiry',
            detail.isEmpty ? 'Details to be added.' : detail,
            'New',
            'Normal',
          ),
        );
        response = 'I recorded a new student enquiry.';
      } else {
        response =
            'There are ${_enquiries.length} learner enquiries: ${_enquiries.map((item) => '${item.name}, ${item.category}, ${item.status}').join('. ')}';
      }
    } else if (command.contains('copilot') ||
        command.startsWith('ask ai') ||
        command.startsWith('ask the ai')) {
      final question = _stripIntent(command, [
        'ask the copilot',
        'ask copilot',
        'ask the ai',
        'ask ai',
      ]);
      _go('AI copilot');
      response = _answerLocally(question.isEmpty ? phrase : question);
      _chat.add(_ChatLine(true, question.isEmpty ? phrase : question));
      _chat.add(_ChatLine(false, response));
      _chatCount++;
    } else if (command.contains('office') ||
        command.contains('hours') ||
        command.contains('where')) {
      _go('Knowledge');
      response = _answerLocally(phrase);
    } else if (command.contains('home') || command.contains('dashboard')) {
      _go('Home');
      response = 'You are on the overview. ' + _homeSummary();
    } else if (command.contains('open documents') ||
        command.contains('show documents')) {
      _go('Documents');
      response = 'You have ${_documents.length} draft documents.';
    } else if (command.contains('open notes') ||
        command.contains('show notes')) {
      _go('Notes');
      response =
          'You have ${_notes.length} saved notes. ' +
          (_notes.isEmpty ? '' : _notes.first.title + ': ' + _notes.first.body);
    }
    if (mounted)
      setState(() {
        _transcript = '“$phrase”\n$response';
        _listening = false;
      });
    if ((consultAi || _isWindowsDesktop) && !stopCommand) {
      _chat.add(_ChatLine(true, phrase));
      _chat.add(_ChatLine(false, response));
    }
    _refreshAssistantPopup();
    if (speakResponse) {
      await _speech.stop();
      await _speak(response);
    }
    _processing = false;
    _refreshAssistantPopup();
    if (resumeVoice && _voiceSession && mounted) {
      await _stopVoiceAfterTask();
    }
  }

  bool _requiresAssistantConfirmation(String action, String command) => false;

  bool _isReadRequest(String command) =>
      RegExp(
        r'^(read|summari[sz]e|tell me|show me|list|find|search|look up|how many|what is|what are|who is|where is|when is|which)\b',
      ).hasMatch(command) ||
      command == 'read screen';

  bool _requiresLocalConfirmation(String command) => false;

  Future<void> _stopVoiceAfterTask() async {
    if (!_voiceSession || !mounted) return;
    _voiceSession = false;
    _processing = false;
    _listening = false;
    _awaitingSessionChoice = false;
    _listenRestartTimer?.cancel();
    _audioCheckTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _speech.stop();
    _transcript = 'Voice session stopped.';
    _refreshAssistantPopup();
  }

  bool _isNavigationRequest(String command) =>
      !command.startsWith('check in ') &&
      !command.startsWith('check out ') &&
      RegExp(r'^(open|show|go to|take me to|navigate to|check)\b')
          .hasMatch(command);

  _DestinationMatch _interpretDestination(String command) {
    final request = command.replaceFirst(
      RegExp(r'^(open|show|go to|take me to|navigate to|check)\s+(the\s+)?'),
      '',
    );
    if (request.contains('call of duty') || request == 'call') {
      return const _DestinationMatch(['Calendar', 'Call log'], .52);
    }
    const aliases = <String, List<String>>{
      'Home': ['home', 'dashboard', 'overview'],
      'Calendar': [
        'calendar',
        'calender',
        'calandar',
        'agenda',
        'schedule',
        'appointments',
        'meetings',
      ],
      'Call log': [
        'call log',
        'phone log',
        'call backs',
        'callbacks',
        'call back list',
        'call-back',
        'call back',
        'calls',
      ],
      'Enquiries': ['enquiries', 'enquiry', 'requests', 'cases'],
      'Notes': ['notes', 'notepad', 'voice notes'],
      'Documents': ['documents', 'document drafts', 'pdfs', 'letters'],
      'Emails': ['emails', 'email drafts', 'draft emails', 'messages'],
      'Learners': ['learners', 'students', 'directory', 'student list'],
      'Knowledge': ['knowledge', 'campus information', 'help articles'],
      'AI copilot': ['ai', 'copilot', 'assistant', 'ai helper'],
      'Visitors': [
        'visitor',
        'visitors',
        'visitor log',
        'check-in',
        'check in list',
      ],
      'Tasks': ['tasks', 'task list', 'to do', 'todo', 'reminders'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any(
        (alias) => request == alias || request.contains(alias),
      )) {
        return _DestinationMatch([
          entry.key,
        ], request == entry.value.first ? .98 : .88);
      }
    }
    return const _DestinationMatch([], .2);
  }

  String? _choosePending(String command) {
    for (final page in _pendingChoices) {
      if (command.contains(page.toLowerCase()) ||
          (page == 'Calendar' &&
              (command.contains('first') || command == 'one')) ||
          (page == 'Call log' &&
              (command.contains('second') || command == 'two'))) {
        return page;
      }
    }
    return null;
  }

  String _summaryFor(String page) => switch (page) {
    'Calendar' => _calendarSummary(),
    'Call log' =>
      '${_calls.where((item) => item.callback).length} call-backs are waiting.',
    'Home' => _homeSummary(),
    'Notes' => '${_notes.length} saved notes.',
    'Documents' => '${_documents.length} draft documents.',
    'Emails' =>
      '${_mailboxAddress == null ? 'No college mailbox is selected' : 'Mailbox setup saved for $_mailboxAddress'}. It is not connected. ${_emails.length} email drafts are saved locally and none have been sent.',
    'Enquiries' => '${_enquiries.length} student enquiries.',
    'Learners' => 'The learner directory is open.',
    'Knowledge' => 'Campus information is open.',
    'AI copilot' => 'The reception copilot is ready.',
    'Visitors' =>
      '${_visitors.where((v) => v.checkedOut == null).length} visitors are currently checked in.',
    'Tasks' =>
      '${_tasks.where((task) => !task.done).length} reception tasks are still open.',
    _ => _pageSummary(),
  };

  void _selectVoiceChoice(String choice) {
    if (!kIsWeb) {
      unawaited(_speech.stop());
    }
    _processing = true;
    unawaited(_handleVoiceCommand(choice));
  }

  bool _hasCreateIntent(String command) => [
    'add ',
    'new ',
    'create ',
    'make ',
    'take ',
    'set ',
    'log ',
    'record ',
    'book ',
    'schedule ',
    'draft ',
    'generate ',
    'write ',
    'compose ',
    'remind ',
  ].any(command.startsWith);
  String _after(String text, List<String> prefixes) {
    for (final prefix in prefixes) {
      final i = text.indexOf(prefix);
      if (i >= 0) return text.substring(i + prefix.length).trim();
    }
    return '';
  }

  String _stripIntent(String text, List<String> phrases) {
    var out = text;
    for (final phrase in phrases) {
      out = out.replaceFirst(phrase, '');
    }
    return out
        .replaceFirst(RegExp(r'^(about|that|saying|for|to)\s+'), '')
        .trim();
  }

  String _cleanStart(String value) =>
      value.replaceFirst(RegExp(r'^(that|saying|about|to)\s+'), '').trim();
  String _titleCase(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  void _go(String page) {
    if (mounted)
      setState(() {
        _page = page;
        _search = '';
      });
  }

  Future<void> _showEmailSetup() async {
    final addressController = TextEditingController(
      text: _mailboxAddress ?? '',
    );
    var provider = _mailboxProvider ?? 'Microsoft 365';
    var invalidAddress = false;
    try {
      final selection = await showDialog<(String, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Set up Student Support email'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose the Student Support mailbox and email service. Your selection is saved on this device. Email sign-in will be available once the college approves secure access.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: addressController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Student Support email address',
                      hintText: 'username@gscollege.edu.za',
                      errorText: invalidAddress
                          ? 'Enter a valid college email address.'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: provider,
                    decoration: const InputDecoration(
                      labelText: 'College email service',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Microsoft 365',
                        child: Text('Microsoft 365'),
                      ),
                      DropdownMenuItem(
                        value: 'Google Workspace',
                        child: Text('Google Workspace'),
                      ),
                      DropdownMenuItem(
                        value: 'Other / IMAP',
                        child: Text('Other / IMAP'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => provider = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'A secure connection still needs the college to confirm its provider and approve access. Do not enter an email password here.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF68776E)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final address = addressController.text.trim();
                  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(address);
                  if (!valid) {
                    setDialogState(() => invalidAddress = true);
                    return;
                  }
                  Navigator.pop(dialogContext, (address, provider));
                },
                child: const Text('Save setup details'),
              ),
            ],
          ),
        ),
      );
      if (selection == null || !mounted) return;
      setState(() {
        _mailboxAddress = selection.$1;
        _mailboxProvider = selection.$2;
      });
      await _persistWindowsData();
      _announce(
        'Mailbox details saved on this device. The email account is not connected yet.',
      );
    } finally {
      addressController.dispose();
    }
  }

  String _homeSummary() =>
      'Today has ${_appointments.where((a) => _sameDay(a.when, DateTime.now())).length} appointments, ${_calls.where((c) => c.callback).length} call-backs, and ${_enquiries.where((e) => e.status != 'Resolved').length} open enquiries.';
  String _calendarSummary() {
    final today =
        _appointments
            .where((item) => _sameDay(item.when, DateTime.now()))
            .toList()
          ..sort((a, b) => a.when.compareTo(b.when));
    if (today.isEmpty) return 'There are no appointments scheduled for today.';
    return 'Today has ${today.length} appointments. ' +
        today
            .map(
              (item) =>
                  '${_time(item.when)}: ${item.title} with ${item.name}, ${item.location}',
            )
            .join('. ');
  }

  DateTime _parseAppointmentDate(String command) {
    final now = DateTime.now();
    var dayOffset = command.contains('day after tomorrow')
        ? 2
        : command.contains('tomorrow')
        ? 1
        : 0;
    final dateMatch = RegExp(r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b')
        .firstMatch(command);
    var year = now.year;
    var month = now.month;
    var day = now.day + dayOffset;
    if (dateMatch != null) {
      final first = int.tryParse(dateMatch.group(1)!) ?? day;
      final second = int.tryParse(dateMatch.group(2)!) ?? month;
      final explicitYear = int.tryParse(dateMatch.group(3) ?? '');
      day = first;
      month = second;
      if (explicitYear != null)
        year = explicitYear < 100 ? 2000 + explicitYear : explicitYear;
    }

    var hour = dayOffset > 0 || dateMatch != null ? 10 : now.hour + 1;
    var minute = 0;
    final timeMatch = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\bat\s+(\d{1,2}):(\d{2})\b',
    ).firstMatch(command);
    if (timeMatch != null) {
      hour =
          int.tryParse(timeMatch.group(1) ?? timeMatch.group(4) ?? '') ?? hour;
      minute =
          int.tryParse(timeMatch.group(2) ?? timeMatch.group(5) ?? '') ?? 0;
      final meridiem = timeMatch.group(3);
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
    }
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
    final date = DateTime(year, month, day, hour, minute);
    return date.isBefore(now) && dateMatch == null && dayOffset == 0
        ? date.add(const Duration(days: 1))
        : date;
  }

  String _spokenDateTime(DateTime value) {
    final today = DateTime.now();
    final dateText = _sameDay(value, today)
        ? 'today'
        : _sameDay(value, today.add(const Duration(days: 1)))
        ? 'tomorrow'
        : '${value.day}/${value.month}';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute == 0
        ? ''
        : ' ${value.minute.toString().padLeft(2, '0')}';
    return '$dateText at $hour$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  String _pageSummary() => switch (_page) {
    'Home' =>
      'Overview. ${_homeSummary()} Upcoming: ${_appointments.take(3).map((a) => '${_time(a.when)} ${a.title} with ${a.name}').join('. ')}',
    'Calendar' => _calendarSummary(),
    'Call log' =>
      'Call log has ${_calls.length} calls. ${_calls.where((c) => c.callback).length} need call-back. ' +
          _calls.take(4).map((c) => '${c.caller}: ${c.reason}').join('. '),
    'Enquiries' =>
      'There are ${_enquiries.length} enquiries. ' +
          _enquiries
              .map(
                (e) =>
                    '${e.name}, ${e.category}, ${e.status}, priority ${e.priority}',
              )
              .join('. '),
    'Notes' =>
      'There are ${_notes.length} notes. ' +
          _notes.take(3).map((n) => '${n.title}: ${n.body}').join('. '),
    'Documents' =>
      'There are ${_documents.length} documents. ' +
          _documents.map((d) => d.title).join('. '),
    'Emails' =>
      '${_mailboxAddress == null ? 'No Student Support mailbox has been selected' : 'Student Support mailbox setup is saved for $_mailboxAddress'}, but it is not connected. There are ${_emails.length} saved email drafts. ' +
          _emails
              .take(3)
              .map((e) => '${e.subject}, to ${e.recipient}')
              .join('. '),
    'Learners' => 'Learner directory with illustrative contacts for registration, academic, financial aid and accessibility support.',
    'Knowledge' => 'Reception reference. Hours and campus directions should be confirmed with Student Support before sharing them as official information.',
    'AI copilot' => 'Liyabona AI is ready for reception questions and app actions. Use the message box to type or the microphone control to speak.',
    'Visitors' =>
      'Visitor register. ${_visitors.where((v) => v.checkedOut == null).length} visitors are currently checked in. ${_visitors.take(4).map((v) => '${v.name}, visiting ${v.host}').join('. ')}',
    'Tasks' =>
      'Task list. ${_tasks.where((task) => !task.done).length} tasks are open. ${_tasks.where((task) => !task.done).take(4).map((task) => task.title).join('. ')}',
    _ => 'More tools for the reception desk.',
  };

  String _answerLocally(String question) {
    final q = question.toLowerCase();
    if (q.contains('today') ||
        q.contains('calendar') ||
        q.contains('appointment'))
      return _calendarSummary();
    if (q.contains('call'))
      return 'There are ${_calls.where((c) => c.callback).length} call-backs pending. ' +
          _calls
              .where((c) => c.callback)
              .map((c) => '${c.caller}: ${c.reason}')
              .join('. ');
    if (q.contains('office') || q.contains('hour') || q.contains('where'))
      return 'The Student Support office is in the main block, next to the library. Reception hours are Monday to Friday, eight in the morning to four in the afternoon.';
    if (q.contains('enquir') || q.contains('request'))
      return 'There are ${_enquiries.length} learner enquiries. ' +
          _enquiries
              .map((e) => '${e.name}: ${e.category}, ${e.status}')
              .join('. ');
    if (q.contains('visitor'))
      return 'There are ${_visitors.where((v) => v.checkedOut == null).length} visitors currently checked in. ' +
          _visitors
              .where((v) => v.checkedOut == null)
              .map((v) => '${v.name}, visiting ${v.host}')
              .join('. ');
    if (q.contains('task') || q.contains('reminder'))
      return 'There are ${_tasks.where((task) => !task.done).length} open desk tasks. ' +
          _tasks
              .where((task) => !task.done)
              .map((task) => task.title)
              .join('. ');
    if (q.contains('note') || q.contains('draft'))
      return 'I can create a note on this device. Say “create a note” followed by the details, and I will save it for you.';
    return 'I can help with the calendar, call-backs, visitors, desk tasks, learner enquiries, notes, email drafts, documents and campus information. The online AI service is unavailable right now, but I can still help with common reception tasks.';
  }

  Future<void> _createRecord(String kind, {String initial = ''}) async {
    final result = await showDialog<_RecordData>(
      context: context,
      builder: (_) => _RecordDialog(kind: kind, initial: initial),
    );
    if (result == null || !mounted) return;
    setState(() {
      switch (kind) {
        case 'Note':
          _notes.insert(0, _Note(result.title, result.detail, DateTime.now()));
          break;
        case 'Call':
          _calls.insert(
            0,
            _Call(
              result.name,
              result.phone,
              result.detail,
              result.callback,
              result.priority,
              DateTime.now(),
            ),
          );
          break;
        case 'Appointment':
          _appointments.insert(
            0,
            _Appointment(
              result.title,
              result.name,
              result.when,
              result.location,
              result.detail,
            ),
          );
          break;
        case 'Enquiry':
          _enquiries.insert(
            0,
            _Enquiry(
              result.name,
              result.category,
              result.detail,
              'New',
              result.priority,
            ),
          );
          break;
        case 'Document':
          _documents.insert(
            0,
            _Document(result.title, result.detail, DateTime.now()),
          );
          break;
        case 'Email':
          _emails.insert(
            0,
            _EmailDraft(
              result.name,
              result.title,
              result.detail,
              DateTime.now(),
            ),
          );
          break;
        case 'Visitor':
          _visitors.insert(
            0,
            _Visitor(result.name, result.title, result.detail, DateTime.now()),
          );
          break;
        case 'Task':
          _tasks.insert(
            0,
            _ReceptionTask(result.title, result.detail, DateTime.now(), false),
          );
          break;
      }
    });
    await _persistWindowsData();
    _announce('$kind saved on this device.');
    await _speak('$kind saved.');
  }

  Widget _pageContent() => switch (_page) {
    'Home' => _HomePage(
      appointments: _appointments,
      calls: _calls,
      enquiries: _enquiries,
      notes: _notes,
      visitorCount: _visitors.where((v) => v.checkedOut == null).length,
      openTaskCount: _tasks.where((task) => !task.done).length,
      onNavigate: _go,
      onCreate: _createRecord,
      onAsk: (q) => unawaited(_askCopilot(q)),
    ),
    'Calendar' => _CalendarPage(
      appointments: _appointments,
      onCreate: () => _createRecord('Appointment'),
      onRead: () => _speak(_calendarSummary()),
    ),
    'Call log' => _CallPage(
      calls: _calls,
      onCreate: () => _createRecord('Call'),
      onRead: () => _speak(_pageSummary()),
    ),
    'Enquiries' => _EnquiryPage(
      enquiries: _enquiries,
      onCreate: () => _createRecord('Enquiry'),
    ),
    'Notes' => _NotesPage(
      notes: _notes,
      onCreate: () => _createRecord('Note'),
      onRead: () => _speak(_pageSummary()),
    ),
    'Documents' => _DocumentsPage(
      documents: _documents,
      onCreate: () => _createRecord('Document'),
    ),
    'Emails' => _EmailsPage(
      drafts: _emails,
      mailboxAddress: _mailboxAddress,
      mailboxProvider: _mailboxProvider,
      onConnect: _showEmailSetup,
      onCreate: () => _createRecord('Email'),
      onRead: () => _speak(_pageSummary()),
    ),
    'Learners' => _LearnersPage(search: _search, onSpeak: (s) => _speak(s)),
    'Knowledge' => _KnowledgePage(
      controller: _knowledgeController,
      onSave: _saveKnowledge,
    ),
    'AI copilot' => _CopilotPage(
      chat: _chat,
      onAsk: _askCopilot,
      busy: _assistantBusy,
      error: _assistantError,
      listening: _voiceSession,
      wakeWordSupported: _isWindowsDesktop,
      wakeWordEnabled: _wakeWordEnabled,
      wakeWordListening: _wakeWordListening,
      onWakeWordChanged: _setWakeWordEnabled,
      onVoice: _toggleVoice,
      onSpeak: (text) => _speak(text, toggle: true),
    ),
    'Visitors' => _VisitorsPage(
      visitors: _visitors,
      onCreate: () => _createRecord('Visitor'),
      onCheckout: (visitor) {
        setState(() => visitor.checkedOut = DateTime.now());
        unawaited(_persistWindowsData());
      },
      onRead: () => _speak(_pageSummary()),
    ),
    'Tasks' => _TasksPage(
      tasks: _tasks,
      onCreate: () => _createRecord('Task'),
      onToggle: (task) {
        setState(() => task.done = !task.done);
        unawaited(_persistWindowsData());
      },
      onRead: () => _speak(_pageSummary()),
    ),
    _ => _MorePage(onNavigate: _go, onSpeak: () => _speak(_pageSummary())),
  };

  @override
  Widget build(BuildContext context) {
    final scale = _largeText ? 1.13 : 1.0;
    final background = _highContrast ? Colors.white : paper;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Campus Reception',
      theme: _makeTheme(_highContrast),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          if (!wide) return _mobileShell(background);
          return Scaffold(
            backgroundColor: background,
            body: Row(
              children: [
                _Sidebar(
                  selected: _page,
                  items: _nav,
                  onSelect: _go,
                  onAssistant: _openAssistantPopup,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopTopbar(
                        highContrast: _highContrast,
                        largeText: _largeText,
                        onContrast: () =>
                            setState(() => _highContrast = !_highContrast),
                        onText: () => setState(() => _largeText = !_largeText),
                        onRead: () => _speak(_pageSummary()),
                      ),
                      if (_voiceSession)
                        _VoiceBanner(
                          listening: _listening,
                          processing: _processing,
                          transcript: _transcript,
                          heard: _heardPhrase,
                          interpretation: _interpretation,
                          confidence: _matchConfidence,
                          choices: _pendingChoices,
                          onChoose: _selectVoiceChoice,
                          onStop: _toggleVoice,
                        ),
                      Expanded(child: _pageContent()),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _actionButtons(),
          );
        },
      ),
    );
  }

  Widget _mobileShell(Color background) {
    const destinations = ['Home', 'Calendar', 'Emails', 'More'];
    final index = destinations.indexOf(_page);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const _BrandIcon(size: 34),
            const SizedBox(width: 9),
            Text(
              _page,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Read this screen aloud',
            onPressed: () => _speak(_pageSummary()),
            icon: const Icon(Icons.volume_up_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Accessibility settings',
            icon: const Icon(Icons.accessibility_new_rounded),
            onSelected: (v) => setState(() {
              if (v == 'text') _largeText = !_largeText;
              if (v == 'contrast') _highContrast = !_highContrast;
            }),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'text',
                child: Text(_largeText ? 'Standard text size' : 'Larger text'),
              ),
              PopupMenuItem(
                value: 'contrast',
                child: Text(
                  _highContrast ? 'Standard contrast' : 'High contrast',
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_voiceSession)
            _VoiceBanner(
              listening: _listening,
              processing: _processing,
              transcript: _transcript,
              heard: _heardPhrase,
              interpretation: _interpretation,
              confidence: _matchConfidence,
              choices: _pendingChoices,
              onChoose: _selectVoiceChoice,
              onStop: _toggleVoice,
            ),
          Expanded(child: _pageContent()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 3 : index,
        onDestinationSelected: (i) => _go(destinations[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline_rounded),
            selectedIcon: Icon(Icons.mark_email_read_rounded),
            label: 'Emails',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'More',
          ),
        ],
      ),
      floatingActionButton: _actionButtons(),
    );
  }

  Widget _actionButtons() => FloatingActionButton(
    heroTag: 'liyabona-ai-button',
    tooltip: _voiceSession
        ? 'Stop Liyabona AI listening'
        : _wakeWordListening
        ? 'Liyabona is listening locally for Assist'
        : 'Start Liyabona AI voice assistant',
    onPressed: () => unawaited(_handleAssistantButton()),
    backgroundColor: forest,
    foregroundColor: Colors.white,
    child: _AnimatedAssistantCharacter(
      active: _voiceSession || _wakeWordListening || _assistantBusy || _ttsSpeaking,
      speaking: _ttsSpeaking,
      listening: _listening || _wakeWordListening,
      size: 46,
    ),
  );

  Future<void> _handleAssistantButton({bool showPopup = true}) async {
    if (_voiceSession) {
      if (showPopup) {
        _closeAssistantPopup();
      } else {
        await _toggleVoice();
      }
      return;
    }
    _wakeLaunchInProgress = true;
    _wakeWordRestartTimer?.cancel();
    if (_wakeWordListening) {
      _wakeWordListening = false;
      await _speech.stop();
    }
    if (showPopup) _openAssistantPopup();
    try {
      await _toggleVoice(greet: true);
    } finally {
      _wakeLaunchInProgress = false;
      if (!_voiceSession) _scheduleWakeWordRestart();
    }
  }

  void _closeAssistantPopup() {
    _voiceSession = false;
    _processing = false;
    _listening = false;
    _audioCheckTimer?.cancel();
    unawaited(_audioRecorder.stop());
    unawaited(_audioSubscription?.cancel());
    _audioSubscription = null;
    unawaited(_speech.stop());
    _stopSpeaking();
    final navigator = _navigatorKey.currentState;
    if (navigator?.canPop() ?? false) navigator!.pop();
  }

  void _openAssistantPopup() {
    if (_assistantPopupOpen) return;
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    _assistantPopupOpen = true;
    showGeneralDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      barrierLabel: 'Close Liyabona AI assistant',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) => StatefulBuilder(
        builder: (context, setPopupState) {
          _popupRebuild = setPopupState;
          return _AssistantPopup(
            busy: _assistantBusy || _processing,
            listening: _voiceSession,
            speaking: _ttsSpeaking,
            error: _assistantError,
            onStopSpeaking: _stopSpeaking,
            onClose: _closeAssistantPopup,
          );
        },
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ).whenComplete(() {
      _popupRebuild = null;
      _assistantPopupOpen = false;
    });
  }
}

ThemeData _makeTheme(bool contrast) {
  final scheme = ColorScheme.fromSeed(
    seedColor: contrast ? Colors.black : forest,
    brightness: Brightness.light,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: contrast ? Colors.white : paper,
    fontFamily: 'Roboto',
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAF9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: teal, width: 1.7),
      ),
      labelStyle: const TextStyle(color: Color(0xFF586860)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: forest,
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: mint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      labelStyle: const TextStyle(color: forest, fontWeight: FontWeight.w600),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.items,
    required this.onSelect,
    required this.onAssistant,
  });
  final String selected;
  final List<_NavItem> items;
  final ValueChanged<String> onSelect;
  final VoidCallback onAssistant;
  @override
  Widget build(BuildContext context) => Container(
    width: 254,
    color: Colors.white,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 22, 18, 22),
            child: Row(
              children: [
                const _BrandIcon(size: 42),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Liyabona',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'RECEPTION DESK',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF77847D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(21, 4, 14, 8),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF89958F),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final item in items)
                  _NavButton(
                    item: item,
                    selected: selected == item.label,
                    onTap: () => onSelect(item.label),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: forest),
                      const SizedBox(width: 8),
                      Text(
                        'Liyabona AI',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Ask it to navigate, write notes, set reminders and manage reception tasks.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFF63736B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAssistant,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Open AI assistant'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: selected ? mint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: selected ? forest : const Color(0xFF65736C),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? forest : const Color(0xFF46574F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DesktopTopbar extends StatelessWidget {
  const _DesktopTopbar({
    required this.highContrast,
    required this.largeText,
    required this.onContrast,
    required this.onText,
    required this.onRead,
  });
  final bool highContrast, largeText;
  final VoidCallback onContrast, onText, onRead;
  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Student Support Services  /  Reception',
            style: TextStyle(
              color: Color(0xFF66756D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Read this screen aloud',
          onPressed: onRead,
          icon: const Icon(Icons.volume_up_outlined),
        ),
        IconButton(
          tooltip: largeText ? 'Standard text' : 'Larger text',
          onPressed: onText,
          icon: const Icon(Icons.text_fields_rounded),
        ),
        IconButton(
          tooltip: highContrast ? 'Standard contrast' : 'High contrast',
          onPressed: onContrast,
          icon: const Icon(Icons.contrast_rounded),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 18,
          backgroundColor: mint,
          child: Text(
            'NM',
            style: TextStyle(
              color: forest,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(size * .31),
    ),
    child: Icon(
      Icons.support_agent_rounded,
      color: Colors.white,
      size: size * .54,
    ),
  );
}

class _VoiceBanner extends StatelessWidget {
  const _VoiceBanner({
    required this.listening,
    required this.processing,
    required this.transcript,
    required this.heard,
    required this.interpretation,
    required this.confidence,
    required this.choices,
    required this.onChoose,
    required this.onStop,
  });
  final bool listening, processing;
  final String transcript, heard, interpretation;
  final double? confidence;
  final List<String> choices;
  final ValueChanged<String> onChoose;
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    decoration: const BoxDecoration(
      color: Color(0xFFEAF4F1),
      border: Border(bottom: BorderSide(color: Color(0xFFD3E7E1))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              processing
                  ? Icons.auto_awesome
                  : listening
                  ? Icons.graphic_eq_rounded
                  : Icons.mic_none_rounded,
              color: forest,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  transcript.isEmpty
                      ? (processing
                            ? 'Working on your request…'
                            : 'Voice session active. Say a command.')
                      : transcript,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: ink),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded, size: 17),
              label: const Text('Stop'),
            ),
          ],
        ),
        if (heard.isNotEmpty) ...[
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD3E7E1)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: teal),
                const Text(
                  'Liyabona AI command interpreter',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: forest,
                  ),
                ),
                Text(
                  interpretation,
                  style: const TextStyle(fontSize: 12, color: ink),
                ),
                if (confidence != null)
                  Text(
                    '${(confidence! * 100).round()}% match',
                    style: const TextStyle(
                      fontSize: 11,
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                for (final choice in choices)
                  ActionChip(
                    label: Text(choice),
                    onPressed: () => onChoose(choice),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.appointments,
    required this.calls,
    required this.enquiries,
    required this.notes,
    required this.visitorCount,
    required this.openTaskCount,
    required this.onNavigate,
    required this.onCreate,
    required this.onAsk,
  });
  final List<_Appointment> appointments;
  final List<_Call> calls;
  final List<_Enquiry> enquiries;
  final List<_Note> notes;
  final int visitorCount, openTaskCount;
  final ValueChanged<String> onNavigate;
  final Future<void> Function(String, {String initial}) onCreate;
  final ValueChanged<String> onAsk;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = appointments.where((a) => _sameDay(a.when, now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final callbacks = calls.where((c) => c.callback).toList();
    final open = enquiries.where((e) => e.status != 'Resolved').length;
    return _PageScroll(
      children: [
        _PageHeading(
          eyebrow: _weekday(now),
          title: 'Good morning, Neo',
          subtitle: 'Here’s what is happening at the reception desk today.',
          trailing: OutlinedButton.icon(
            onPressed: () => onNavigate('Calendar'),
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('View calendar'),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 930
                ? 3
                : constraints.maxWidth > 580
                ? 2
                : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 1 ? 3.6 : 1.65,
              children: [
                _MetricCard(
                  label: 'Today’s appointments',
                  value: '${today.length}',
                  hint:
                      'Next at ${today.isEmpty ? '—' : _time(today.first.when)}',
                  icon: Icons.calendar_month_rounded,
                  tone: mint,
                  onTap: () => onNavigate('Calendar'),
                ),
                _MetricCard(
                  label: 'Call-backs to make',
                  value: '${callbacks.length}',
                  hint: 'Two marked for follow-up',
                  icon: Icons.call_missed_outgoing_rounded,
                  tone: amber,
                  onTap: () => onNavigate('Call log'),
                ),
                _MetricCard(
                  label: 'Open enquiries',
                  value: '$open',
                  hint: 'Across learner support',
                  icon: Icons.assignment_outlined,
                  tone: const Color(0xFFEAF0FB),
                  onTap: () => onNavigate('Enquiries'),
                ),
                _MetricCard(
                  label: 'Notes saved today',
                  value: '${notes.length}',
                  hint: 'Saved on this device',
                  icon: Icons.sticky_note_2_outlined,
                  tone: const Color(0xFFF1ECFA),
                  onTap: () => onNavigate('Notes'),
                ),
                _MetricCard(
                  label: 'Visitors on site',
                  value: '$visitorCount',
                  hint: 'Remember visitor sign-out',
                  icon: Icons.badge_outlined,
                  tone: const Color(0xFFE8F2F8),
                  onTap: () => onNavigate('Visitors'),
                ),
                _MetricCard(
                  label: 'Open desk tasks',
                  value: '$openTaskCount',
                  hint: 'Daily reminders and follow-ups',
                  icon: Icons.task_alt_rounded,
                  tone: const Color(0xFFF7EDE7),
                  onTap: () => onNavigate('Tasks'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Quick actions',
          trailing: const Text(
            'Choose a task',
            style: TextStyle(color: Color(0xFF76827B), fontSize: 11),
          ),
        ),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 760
                ? 4
                : c.maxWidth > 480
                ? 2
                : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: cols == 1 ? 4 : 1.8,
              children: [
                _QuickAction(
                  icon: Icons.call_rounded,
                  title: 'Log a call',
                  detail: 'Record a message',
                  color: const Color(0xFFE5F0FB),
                  onTap: () => onCreate('Call'),
                ),
                _QuickAction(
                  icon: Icons.edit_note_rounded,
                  title: 'New note',
                  detail: 'Type or dictate',
                  color: mint,
                  onTap: () => onCreate('Note'),
                ),
                _QuickAction(
                  icon: Icons.event_available_rounded,
                  title: 'Book appointment',
                  detail: 'Schedule a visit',
                  color: amber,
                  onTap: () => onCreate('Appointment'),
                ),
                _QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Draft a document',
                  detail: 'Start with the copilot',
                  color: const Color(0xFFF0EBFA),
                  onTap: () => onCreate('Document'),
                ),
                _QuickAction(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Check in visitor',
                  detail: 'Record who is on campus',
                  color: const Color(0xFFE8F2F8),
                  onTap: () => onCreate('Visitor'),
                ),
                _QuickAction(
                  icon: Icons.add_task_rounded,
                  title: 'Add desk task',
                  detail: 'Track a follow-up',
                  color: const Color(0xFFF7EDE7),
                  onTap: () => onCreate('Task'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > 820;
            final left = _PanelCard(
              title: 'Coming up today',
              trailing: TextButton(
                onPressed: () => onNavigate('Calendar'),
                child: const Text('Full calendar'),
              ),
              child: today.isEmpty
                  ? const _EmptyInline('No appointments today.')
                  : Column(
                      children: [
                        for (final a in today.take(3)) _AppointmentRow(item: a),
                      ],
                    ),
            );
            final right = _CallbackPanel(
              calls: callbacks.take(2).toList(),
              onAll: () => onNavigate('Call log'),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: right),
                    ],
                  )
                : Column(children: [left, const SizedBox(height: 12), right]);
          },
        ),
        const SizedBox(height: 22),
        _CopilotPromo(onAsk: onAsk, onOpen: () => onNavigate('AI copilot')),
        const SizedBox(height: 18),
        const _LocalNotice(),
      ],
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1260),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 110),
        children: children,
      ),
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
  });
  final String title, subtitle;
  final String? eyebrow;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    eyebrow!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.25,
                      fontWeight: FontWeight.w900,
                      color: teal,
                    ),
                  ),
                ),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900, color: ink),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF68776E),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) const SizedBox(width: 10),
        if (trailing != null && MediaQuery.sizeOf(context).width > 580)
          trailing!,
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.tone,
    required this.onTap,
  });
  final String label, value, hint;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: forest),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: Color(0xFF89958F),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4D5C54),
              ),
            ),
            Text(
              hint,
              style: const TextStyle(fontSize: 10, color: Color(0xFF87928B)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: forest),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF78857E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF85928A)),
          ],
        ),
      ),
    ),
  );
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.item});
  final _Appointment item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 45,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _time(item.when),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: forest,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.name} · ${item.location}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF75827B)),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 17, color: Color(0xFF8D9992)),
      ],
    ),
  );
}

class _CallbackPanel extends StatelessWidget {
  const _CallbackPanel({required this.calls, required this.onAll});
  final List<_Call> calls;
  final VoidCallback onAll;
  @override
  Widget build(BuildContext context) => _PanelCard(
    title: 'Call-backs',
    trailing: TextButton(onPressed: onAll, child: const Text('View all')),
    child: calls.isEmpty
        ? const _EmptyInline('No call-backs waiting.')
        : Column(
            children: [
              for (final call in calls)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: amber,
                        child: Icon(
                          Icons.call_missed_outgoing_rounded,
                          size: 15,
                          color: Color(0xFF926210),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              call.caller,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: ink,
                              ),
                            ),
                            Text(
                              call.reason,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF77847D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 17,
                        color: Color(0xFF8D9992),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _CopilotPromo extends StatelessWidget {
  const _CopilotPromo({required this.onAsk, required this.onOpen});
  final ValueChanged<String> onAsk;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF174C42), Color(0xFF1D7163)],
      ),
      borderRadius: BorderRadius.circular(19),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 640;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFB7E5D7),
                  size: 17,
                ),
                const SizedBox(width: 7),
                const Text(
                  'LIYABONA AI ASSISTANT',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: Color(0xFFB7E5D7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'A calm second pair of hands.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Ask for a summary, draft a note or get help with a reception process.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .78),
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in [
                  'Summarise today',
                  'What needs follow-up?',
                ])
                  ActionChip(
                    label: Text(query),
                    backgroundColor: Colors.white,
                    onPressed: () => onAsk(query),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Open AI copilot'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        );
        return compact
            ? text
            : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 28),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFD1F4E9),
                      size: 49,
                    ),
                  ),
                ],
              );
      },
    ),
  );
}

class _LocalNotice extends StatelessWidget {
  const _LocalNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF3F1),
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: Color(0xFF66766D)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'The microphone starts only when you open a voice session. Online, Liyabona sends short audio clips through its secure Vercel service to Google Gemini for English (South Africa) transcription and command handling. Audio clips are held in memory by the app and are not saved as recordings; Google processes submitted audio under its API data terms. When online recognition is unavailable, the app can use the device speech service instead. College systems and mailboxes are not connected.',
            style: TextStyle(
              fontSize: 10,
              height: 1.45,
              color: Color(0xFF5F6E66),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        const Icon(Icons.inbox_outlined, size: 18, color: Color(0xFF8A9790)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF7A8780)),
        ),
      ],
    ),
  );
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({
    required this.appointments,
    required this.onCreate,
    required this.onRead,
  });
  final List<_Appointment> appointments;
  final VoidCallback onCreate, onRead;
  @override
  Widget build(BuildContext context) {
    final sorted = appointments.toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return _PageScroll(
      children: [
        _PageHeading(
          title: 'Calendar',
          subtitle: 'Appointments and planned student support meetings.',
          trailing: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('New appointment'),
          ),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Upcoming appointments',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            IconButton(
              tooltip: 'Read appointments aloud',
              onPressed: onRead,
              icon: const Icon(Icons.volume_up_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sorted.isEmpty)
          const _PanelCard(
            title: 'Your calendar is clear',
            child: _EmptyInline('Create an appointment to get started.'),
          )
        else
          for (final a in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _AppointmentCard(item: a),
            ),
        const SizedBox(height: 8),
        const _LocalNotice(),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item});
  final _Appointment item;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 55,
            height: 58,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${item.when.day}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: forest,
                  ),
                ),
                Text(
                  _month(item.when.month),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: forest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.name} · ${item.category}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D7B73),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: teal),
                    const SizedBox(width: 5),
                    Text(
                      '${_weekday(item.when)} · ${_time(item.when)}  •  ${item.location}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6D7B73),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Read appointment',
            onPressed: () => FlutterTts().speak(
              '${item.title}. ${item.name}. ${_weekday(item.when)} at ${_time(item.when)}. ${item.location}',
            ),
            icon: const Icon(Icons.volume_up_outlined, size: 19),
          ),
        ],
      ),
    ),
  );
}

class _CallPage extends StatelessWidget {
  const _CallPage({
    required this.calls,
    required this.onCreate,
    required this.onRead,
  });
  final List<_Call> calls;
  final VoidCallback onCreate, onRead;
  @override
  Widget build(BuildContext context) {
    final callbacks = calls.where((c) => c.callback).length;
    return _PageScroll(
      children: [
        _PageHeading(
          title: 'Call log',
          subtitle:
              'Capture messages, priorities and the follow-up that comes next.',
          trailing: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_call),
            label: const Text('Log a call'),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SmallCount(
              label: 'Total calls',
              value: '${calls.length}',
              icon: Icons.call_rounded,
            ),
            _SmallCount(
              label: 'Need call-back',
              value: '$callbacks',
              icon: Icons.call_missed_outgoing_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent calls',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Read call log aloud',
              onPressed: onRead,
              icon: const Icon(Icons.volume_up_outlined),
            ),
          ],
        ),
        const SizedBox(height: 9),
        for (final c in calls)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _CallCard(item: c),
          ),
        const _LocalNotice(),
      ],
    );
  }
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.item});
  final _Call item;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: item.callback ? amber : mint,
            child: Icon(
              Icons.call_received_rounded,
              color: item.callback ? const Color(0xFF94651B) : forest,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.caller,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                    ),
                    _StatusPill(
                      text: item.callback ? 'Call-back' : 'Logged',
                      warm: item.callback,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.phone.isEmpty ? 'No number' : item.phone} · ${_time(item.when)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7B8881),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF43544B),
                  ),
                ),
                const SizedBox(height: 7),
                _StatusPill(
                  text: '${item.priority} priority',
                  warm: item.priority == 'High',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Read call aloud',
            onPressed: () => FlutterTts().speak(
              '${item.caller}. ${item.reason}. ${item.callback ? 'Call-back requested.' : ''}',
            ),
            icon: const Icon(Icons.volume_up_outlined, size: 18),
          ),
        ],
      ),
    ),
  );
}

class _EnquiryPage extends StatelessWidget {
  const _EnquiryPage({required this.enquiries, required this.onCreate});
  final List<_Enquiry> enquiries;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      _PageHeading(
        title: 'Student enquiries',
        subtitle: 'A clear queue for requests that need a helpful next step.',
        trailing: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('New enquiry'),
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          _StatusPill(
            text: '${enquiries.where((e) => e.status == 'New').length} new',
          ),
          _StatusPill(
            text:
                '${enquiries.where((e) => e.status == 'In progress').length} in progress',
            warm: true,
          ),
          _StatusPill(
            text:
                '${enquiries.where((e) => e.status == 'Waiting').length} waiting',
            warm: true,
          ),
        ],
      ),
      const SizedBox(height: 14),
      for (final e in enquiries)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: mint,
                    child: Text(
                      e.name.isEmpty ? '?' : e.name[0],
                      style: const TextStyle(
                        color: forest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                        Text(
                          e.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: teal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          e.detail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C7A72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(text: e.status, warm: e.status == 'Waiting'),
                      const SizedBox(height: 7),
                      _StatusPill(
                        text: '${e.priority} priority',
                        warm: e.priority == 'High',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 9),
      const _LocalNotice(),
    ],
  );
}

class _NotesPage extends StatelessWidget {
  const _NotesPage({
    required this.notes,
    required this.onCreate,
    required this.onRead,
  });
  final List<_Note> notes;
  final VoidCallback onCreate, onRead;

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      _PageHeading(
        title: 'Working notes',
        subtitle: 'Capture handovers, reminders and the details that help the next person.',
        trailing: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('New note'),
        ),
      ),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Saved on this device',
              style: TextStyle(fontSize: 11, color: Color(0xFF728078)),
            ),
          ),
          IconButton(
            tooltip: 'Read notes aloud',
            onPressed: onRead,
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (notes.isEmpty)
        const _PanelCard(
          title: 'No notes yet',
          child: _EmptyInline(
            'Use New note or dictate one with the voice assistant.',
          ),
        )
      else
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 750 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 2 ? 2.1 : 3.1,
              children: [
                for (final n in notes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                color: teal,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: ink,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Read note aloud',
                                onPressed: () =>
                                    FlutterTts().speak('${n.title}. ${n.body}'),
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: Text(
                              n.body,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Color(0xFF59675F),
                              ),
                            ),
                          ),
                          Text(
                            '${_weekday(n.when)} · ${_time(n.when)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF8A958F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      const SizedBox(height: 12),
      const _LocalNotice(),
    ],
  );
}

class _DocumentsPage extends StatelessWidget {
  const _DocumentsPage({required this.documents, required this.onCreate});
  final List<_Document> documents;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      _PageHeading(
        title: 'Documents',
        subtitle: 'Draft letters, confirmations and printable reception forms.',
        trailing: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create document'),
        ),
      ),
      const _PanelCard(
        title: 'Quick templates',
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _TemplateChip(
              'Appointment confirmation',
              Icons.event_available_outlined,
            ),
            _TemplateChip('Call-back slip', Icons.phone_callback_outlined),
            _TemplateChip('Enquiry receipt', Icons.mark_email_read_outlined),
            _TemplateChip('Daily handover', Icons.summarize_outlined),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle(title: 'Recent drafts'),
      const SizedBox(height: 9),
      for (final d in documents)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: mint,
                child: Icon(Icons.description_outlined, color: forest),
              ),
              title: Text(
                d.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${d.summary} · ${_time(d.when)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(d.title),
                  content: Text(d.summary),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 10),
      const _LocalNotice(),
    ],
  );
}

class _EmailsPage extends StatelessWidget {
  const _EmailsPage({
    required this.drafts,
    required this.mailboxAddress,
    required this.mailboxProvider,
    required this.onConnect,
    required this.onCreate,
    required this.onRead,
  });

  final List<_EmailDraft> drafts;
  final String? mailboxAddress, mailboxProvider;
  final VoidCallback onConnect;
  final VoidCallback onCreate, onRead;

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      _PageHeading(
        title: 'Emails',
        subtitle: 'Set up the college Student Support mailbox and manage message drafts.',
      ),
      _PanelCard(
        title: 'Student Support mailbox',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: amber,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off_rounded, size: 14, color: ink),
              SizedBox(width: 5),
              Text(
                'Not connected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mailboxAddress ?? 'No mailbox selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        mailboxProvider == null
                            ? 'Use the college Student Support address'
                            : '$mailboxProvider · setup details saved on this device',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF68776E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'To connect Student Support email, the college must confirm its mail provider and approve secure access. Drafts can be reviewed here; messages are not sent from Liyabona yet.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF68776E),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.settings_outlined),
              label: Text(
                mailboxAddress == null
                    ? 'Set up college email'
                    : 'Edit setup details',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _SectionTitle(
        title: 'Drafts',
        trailing: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('New draft'),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Review AI-assisted replies before sending. Drafts remain on this device until a mailbox is connected.',
              style: TextStyle(fontSize: 11, color: Color(0xFF728078)),
            ),
          ),
          IconButton(
            tooltip: 'Read email drafts aloud',
            onPressed: onRead,
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (drafts.isEmpty)
        const _PanelCard(
          title: 'No email drafts yet',
          child: _EmptyInline(
            'Ask Liyabona to draft an email, or create one here.',
          ),
        )
      else
        for (final draft in drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: mint,
                  child: Icon(Icons.mark_email_unread_outlined, color: forest),
                ),
                title: Text(
                  draft.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'To: ${draft.recipient} · Draft · ${_time(draft.when)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(draft.subject),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'To: ${draft.recipient}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          SelectableText(draft.body),
                          const SizedBox(height: 16),
                          const Text(
                            'This is a draft. It has not been sent.',
                            style: TextStyle(fontSize: 11, color: forest),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      const SizedBox(height: 10),
      const _LocalNotice(),
    ],
  );
}

class _VisitorsPage extends StatelessWidget {
  const _VisitorsPage({
    required this.visitors,
    required this.onCreate,
    required this.onCheckout,
    required this.onRead,
  });
  final List<_Visitor> visitors;
  final VoidCallback onCreate, onRead;
  final ValueChanged<_Visitor> onCheckout;

  @override
  Widget build(BuildContext context) {
    final inside = visitors.where((v) => v.checkedOut == null).length;
    return _PageScroll(
      children: [
        _PageHeading(
          title: 'Visitor register',
          subtitle: 'Keep a simple record of visitors currently on campus and who they came to see.',
          trailing: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Check in visitor'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _SmallCount(
                label: 'on campus',
                value: '$inside',
                icon: Icons.groups_outlined,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Read visitor register aloud',
              onPressed: onRead,
              icon: const Icon(Icons.volume_up_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (visitors.isEmpty)
          const _PanelCard(
            title: 'No visitor records',
            child: _EmptyInline('Check in a visitor when they arrive.'),
          )
        else
          for (final visitor in visitors)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: visitor.checkedOut == null ? mint : line,
                    child: Icon(
                      visitor.checkedOut == null
                          ? Icons.person_pin_circle_outlined
                          : Icons.person_outline,
                      color: forest,
                    ),
                  ),
                  title: Text(
                    visitor.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Visiting ${visitor.host} · ${visitor.purpose}\nArrived ${_time(visitor.checkedIn)}${visitor.checkedOut == null ? '' : ' · Left ${_time(visitor.checkedOut!)}'}',
                  ),
                  isThreeLine: true,
                  trailing: visitor.checkedOut == null
                      ? OutlinedButton(
                          onPressed: () => onCheckout(visitor),
                          child: const Text('Check out'),
                        )
                      : const _StatusPill(text: 'Checked out'),
                ),
              ),
            ),
        const SizedBox(height: 10),
        const _LocalNotice(),
      ],
    );
  }
}

class _TasksPage extends StatelessWidget {
  const _TasksPage({
    required this.tasks,
    required this.onCreate,
    required this.onToggle,
    required this.onRead,
  });
  final List<_ReceptionTask> tasks;
  final VoidCallback onCreate, onRead;
  final ValueChanged<_ReceptionTask> onToggle;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => !task.done).length;
    return _PageScroll(
      children: [
        _PageHeading(
          title: 'Reception tasks',
          subtitle: 'A practical list for reminders, handovers and follow-ups.',
          trailing: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_task),
            label: const Text('Add task'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _SmallCount(
                label: 'open',
                value: '$open',
                icon: Icons.pending_actions_outlined,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Read task list aloud',
              onPressed: onRead,
              icon: const Icon(Icons.volume_up_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          const _PanelCard(
            title: 'No tasks yet',
            child: _EmptyInline('Add a reminder or follow-up for the desk.'),
          )
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: CheckboxListTile(
                  value: task.done,
                  onChanged: (_) => onToggle(task),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    '${task.detail} · ${task.done ? 'Completed' : 'Added ${_time(task.created)}'}',
                  ),
                ),
              ),
            ),
        const SizedBox(height: 10),
        const _LocalNotice(),
      ],
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 16, color: forest),
    label: Text(label),
    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label template selected. Use Create document to draft it.',
        ),
      ),
    ),
  );
}

class _LearnersPage extends StatefulWidget {
  const _LearnersPage({required this.search, required this.onSpeak});
  final String search;
  final ValueChanged<String> onSpeak;
  @override
  State<_LearnersPage> createState() => _LearnersPageState();
}

class _LearnersPageState extends State<_LearnersPage> {
  late final _search = TextEditingController(text: widget.search);
  final _students = const [
    ('Lerato Mokoena', 'Registration support', '071 555 0141'),
    ('Thabo Khumalo', 'Academic support', '072 555 0108'),
    ('Amina Dlamini', 'Financial aid', '073 555 0125'),
    ('Sibusiso Ndlovu', 'Accessibility support', '074 555 0166'),
    ('Neo Nkosi', 'New learner', '078 555 0104'),
  ];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.toLowerCase();
    final filtered = _students
        .where(
          (s) =>
              s.$1.toLowerCase().contains(q) || s.$2.toLowerCase().contains(q),
        )
        .toList();
    return _PageScroll(
      children: [
        _PageHeading(
          title: 'Learner directory',
          subtitle: 'Illustrative contacts for registration, academic, financial aid and accessibility support.',
        ),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Search learners',
            hintText: 'Name or support area',
          ),
        ),
        const SizedBox(height: 14),
        for (final s in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: mint,
                  child: Text(
                    s.$1[0],
                    style: const TextStyle(
                      color: forest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  s.$1,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${s.$2} · ${s.$3}'),
                trailing: IconButton(
                  tooltip: 'Read learner information',
                  onPressed: () =>
                      widget.onSpeak('${s.$1}. ${s.$2}. Phone ${s.$3}'),
                  icon: const Icon(Icons.volume_up_outlined),
                ),
              ),
            ),
          ),
        if (filtered.isEmpty)
          const _EmptyInline('No learner matches this search.'),
        const SizedBox(height: 10),
        const _LocalNotice(),
      ],
    );
  }
}

class _KnowledgePage extends StatefulWidget {
  const _KnowledgePage({required this.controller, required this.onSave});
  final TextEditingController controller;
  final Future<void> Function(String) onSave;

  @override
  State<_KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<_KnowledgePage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      const _PageHeading(
        title: 'Reception knowledge',
        subtitle: 'Add information that helps Liyabona understand your work and answer consistently.',
      ),
      const SizedBox(height: 12),
      TextField(
        controller: widget.controller,
        minLines: 8,
        maxLines: 18,
        maxLength: 5000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Information for Liyabona',
          hintText: 'Type or paste helpful information here. For example:\n• My role and preferred name\n• Confirmed reception hours and campus directions\n• Common terms and the processes I follow\n• Accessibility or communication preferences',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 10),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'This information is saved on this device. When you ask Liyabona AI for help, this knowledge and saved Liyabona records are sent to Gemini with your request. Do not paste passwords or confidential learner information. Mark campus procedures as confirmed only when Student Support has approved them.',
          ),
        ),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save knowledge'),
        ),
      ),
    ],
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(widget.controller.text);
    if (mounted) setState(() => _saving = false);
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: mint,
            child: Icon(icon, color: forest, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF607067),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Read answer aloud',
            onPressed: () => FlutterTts().speak('$title. $body'),
            icon: const Icon(Icons.volume_up_outlined, size: 19),
          ),
        ],
      ),
    ),
  );
}

class _CopilotPage extends StatefulWidget {
  const _CopilotPage({
    required this.chat,
    required this.onAsk,
    required this.busy,
    required this.error,
    required this.listening,
    required this.wakeWordSupported,
    required this.wakeWordEnabled,
    required this.wakeWordListening,
    required this.onWakeWordChanged,
    required this.onVoice,
    required this.onSpeak,
  });
  final List<_ChatLine> chat;
  final Future<void> Function(String) onAsk;
  final bool busy;
  final String error;
  final bool listening;
  final bool wakeWordSupported;
  final bool wakeWordEnabled;
  final bool wakeWordListening;
  final ValueChanged<bool> onWakeWordChanged;
  final VoidCallback onVoice;
  final ValueChanged<String> onSpeak;
  @override
  State<_CopilotPage> createState() => _CopilotPageState();
}

class _CopilotPageState extends State<_CopilotPage> {
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    _input.clear();
    unawaited(widget.onAsk(q));
  }

  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      _PageHeading(
        title: 'Reception copilot',
        subtitle: 'Your AI assistant is available from every screen for questions and reception actions.',
      ),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF174C42), Color(0xFF1D7163)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0x35FFFFFF),
              child: Icon(Icons.auto_awesome, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liyabona AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.error.isNotEmpty
                        ? 'AI service unavailable · built-in commands remain available'
                        : widget.busy
                        ? 'Liyabona AI is working on your request…'
                        : 'AI assistant · available throughout reception',
                    style: const TextStyle(
                      color: Color(0xFFD4E9E3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _PanelCard(
        title: 'How voice requests are understood',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your voice → recognised words → interpreter checks available screens and actions → app responds or asks you to clarify.',
              style: TextStyle(fontSize: 13, height: 1.5, color: ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'The assistant can open screens and manage notes, tasks, calls, appointments, visitor check-ins and enquiries. It asks a follow-up when key details are unclear.',
              style: TextStyle(fontSize: 12, height: 1.45, color: forest),
            ),
            const SizedBox(height: 8),
            const Text(
              'Liyabona AI performs app actions directly. Use the microphone here when you want to speak; you can also type requests.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: forest,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Windows: click the small Liyabona microphone button or press Control + Alt + Space to start a voice session without restoring the full app window. Listening stops after each request. The microphone stays off until activated unless you turn on the optional Assist wake word. If Gemini is offline or audio transcription takes more than eight seconds, Windows switches to built-in speech recognition. If Liyabona cannot make out the words, it says “Repeat again.” To read an email, document or other app, switch to it and say “read” or press Control + Alt + R. Screen text is read locally in sections; say “continue reading” or “repeat” for voice navigation. Reading is read-only and does not send screen text to Gemini or change the other app.',
              style: TextStyle(fontSize: 12, height: 1.5, color: ink),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (widget.wakeWordSupported) ...[
        _PanelCard(
          title: 'Assist wake word',
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: widget.wakeWordEnabled,
            onChanged: widget.onWakeWordChanged,
            title: const Text('Say “Assist” to wake Liyabona'),
            subtitle: Text(
              widget.wakeWordListening
                  ? 'Microphone is on. Windows listens locally for “Assist”.'
                  : widget.wakeWordEnabled
                  ? 'Wake word is enabled. Waiting for Windows speech recognition.'
                  : 'Off by default. Turning this on keeps the microphone active locally while Liyabona is open.',
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
      _PanelCard(
        title: 'Try asking',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final prompt in [
              'Summarise today’s appointments',
              'What needs a call-back?',
              'Remind me to prepare the welcome packs',
              'Check in a visitor named Sam',
              'Open the visitor register',
            ])
              ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 14),
                label: Text(prompt),
                onPressed: () => widget.onAsk(prompt),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        constraints: const BoxConstraints(minHeight: 260),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in widget.chat)
              Align(
                alignment: line.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: line.user ? mint : const Color(0xFFF5F7F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!line.user)
                        const Padding(
                          padding: EdgeInsets.only(right: 8, top: 2),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: teal,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          line.text,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: ink,
                          ),
                        ),
                      ),
                      if (!line.user)
                        IconButton(
                          tooltip: 'Read answer aloud',
                          onPressed: () => widget.onSpeak(line.text),
                          icon: const Icon(Icons.volume_up_outlined, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (widget.busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Liyabona AI is thinking…'),
            ],
          ),
        ),
      Row(
        children: [
          Semantics(
            button: true,
            label: widget.listening
                ? 'Stop speaking to Liyabona AI'
                : 'Speak to Liyabona AI',
            child: IconButton.filledTonal(
              tooltip: widget.listening
                  ? 'Stop voice input'
                  : 'Speak to Liyabona AI',
              onPressed: widget.onVoice,
              icon: Icon(
                widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
              ),
              style: IconButton.styleFrom(
                foregroundColor: widget.listening ? Colors.white : forest,
                backgroundColor: widget.listening
                    ? const Color(0xFF9D3427)
                    : mint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !widget.busy,
              maxLength: 600,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                labelText: 'Tell Liyabona AI what you need',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Send question',
            child: IconButton.filled(
              onPressed: widget.busy ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const _LocalNotice(),
    ],
  );
}

class _AssistantPopup extends StatelessWidget {
  const _AssistantPopup({
    required this.busy,
    required this.listening,
    required this.speaking,
    required this.error,
    required this.onStopSpeaking,
    required this.onClose,
  });

  final bool busy, listening, speaking;
  final String error;
  final VoidCallback onStopSpeaking, onClose;

  @override
  Widget build(BuildContext context) {
    final active = busy || listening || speaking;
    final status = listening
        ? 'Listening to you'
        : speaking
        ? 'Speaking'
        : busy
        ? 'Working on your request'
        : 'Ready when you are';
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 88,
        ),
        child: Material(
          color: Colors.white,
          elevation: 16,
          shadowColor: forest.withValues(alpha: .22),
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 276,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  _AnimatedAssistantCharacter(
                    active: active,
                    speaking: speaking,
                    listening: listening,
                    size: 64,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Liyabona AI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: forest,
                          ),
                        ),
                        if (error.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            error,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: amber),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (speaking)
                    IconButton(
                      tooltip: 'Stop the spoken answer',
                      onPressed: onStopSpeaking,
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: forest,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Stop Liyabona AI and close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedAssistantCharacter extends StatefulWidget {
  const _AnimatedAssistantCharacter({
    required this.active,
    required this.speaking,
    required this.listening,
    required this.size,
  });
  final bool active, speaking, listening;
  final double size;

  @override
  State<_AnimatedAssistantCharacter> createState() =>
      _AnimatedAssistantCharacterState();
}

class _AnimatedAssistantCharacterState
    extends State<_AnimatedAssistantCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _motion.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AnimatedAssistantCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _motion.repeat(reverse: true);
    if (!widget.active && oldWidget.active)
      _motion.animateTo(0, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, child) => Transform.scale(
      scale: 1 + (_motion.value * (widget.active ? .055 : .015)),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mint,
                boxShadow: [
                  BoxShadow(
                    color: teal.withValues(alpha: .15 + (_motion.value * .14)),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: widget.size * .78,
              height: widget.size * .78,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF278B7C), Color(0xFF14574D)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AssistantEye(
                        blink: _motion.value > .92 && widget.active,
                      ),
                      SizedBox(width: widget.size * .12),
                      _AssistantEye(
                        blink: _motion.value > .92 && widget.active,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: widget.speaking ? 19 + (_motion.value * 7) : 18,
                    height: widget.speaking ? 10 + (_motion.value * 8) : 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 1,
              child: Container(
                width: 4,
                height: 10,
                decoration: BoxDecoration(
                  color: teal,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3BF5C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            if (widget.listening)
              Positioned(
                right: 0,
                top: 2,
                child: Icon(Icons.graphic_eq_rounded, size: 17, color: forest),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AssistantEye extends StatelessWidget {
  const _AssistantEye({required this.blink});
  final bool blink;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 100),
    width: 8,
    height: blink ? 2 : 8,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _MorePage extends StatelessWidget {
  const _MorePage({required this.onNavigate, required this.onSpeak});
  final ValueChanged<String> onNavigate;
  final VoidCallback onSpeak;
  @override
  Widget build(BuildContext context) => _PageScroll(
    children: [
      const _PageHeading(
        title: 'More reception tools',
        subtitle: 'Explore the reception workspace.',
      ),
      for (final item in const [
        ('Call log', Icons.call_outlined, 'Call history and call-backs'),
        ('Enquiries', Icons.assignment_outlined, 'Requests and follow-ups'),
        ('Notes', Icons.sticky_note_2_outlined, 'Working notes and handovers'),
        (
          'Documents',
          Icons.description_outlined,
          'Letters and printable forms',
        ),
        (
          'Emails',
          Icons.mark_email_unread_outlined,
          'Draft messages for review',
        ),
        ('Learners', Icons.people_alt_outlined, 'Learner contact directory'),
        ('Knowledge', Icons.menu_book_outlined, 'Common campus answers'),
        ('AI copilot', Icons.auto_awesome_rounded, 'Ask or dictate a question'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: mint,
                child: Icon(item.$2, color: forest),
              ),
              title: Text(
                item.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(item.$3),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onNavigate(item.$1),
            ),
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: onSpeak,
        icon: const Icon(Icons.volume_up_outlined),
        label: const Text('Read this page aloud'),
      ),
      const SizedBox(height: 16),
      const _LocalNotice(),
    ],
  );
}

class _SmallCount extends StatelessWidget {
  const _SmallCount({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: teal),
        const SizedBox(width: 7),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6D7B73)),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, this.warm = false});
  final String text;
  final bool warm;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: warm ? amber : mint,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: warm ? const Color(0xFF805910) : forest,
      ),
    ),
  );
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.kind, this.initial = ''});
  final String kind, initial;
  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  late final _title = TextEditingController(
        text: widget.kind == 'Note' ? 'Voice note' : '',
      ),
      _name = TextEditingController(),
      _detail = TextEditingController(text: widget.initial),
      _phone = TextEditingController(),
      _when = TextEditingController(text: 'Tomorrow, 10:00'),
      _location = TextEditingController(text: 'Student Support office');
  bool _callback = true;
  String _priority = 'Normal', _category = 'General enquiry';
  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _detail.dispose();
    _phone.dispose();
    _when.dispose();
    _location.dispose();
    super.dispose();
  }

  String get _headline => switch (widget.kind) {
    'Note' => 'Create a working note',
    'Call' => 'Log an incoming call',
    'Appointment' => 'Book an appointment',
    'Enquiry' => 'Create a student enquiry',
    'Visitor' => 'Check in a visitor',
    'Task' => 'Add a reception task',
    'Email' => 'Draft an email',
    _ => 'Draft a document',
  };
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: Text(
        _headline,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: width > 650 ? 520 : width * .85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.kind == 'Call' ||
                  widget.kind == 'Appointment' ||
                  widget.kind == 'Enquiry' ||
                  widget.kind == 'Visitor' ||
                  widget.kind == 'Email')
                TextField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: switch (widget.kind) {
                      'Call' => 'Caller name',
                      'Visitor' => 'Visitor name',
                      'Email' => 'Recipient name or email address',
                      _ => 'Learner name',
                    },
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
              if (widget.kind == 'Call') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Call-back number',
                    prefixIcon: Icon(Icons.call_outlined),
                  ),
                ),
              ],
              if (widget.kind == 'Appointment') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Meeting purpose',
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _when,
                  decoration: const InputDecoration(
                    labelText: 'Date and time',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
              if (widget.kind == 'Note' ||
                  widget.kind == 'Document' ||
                  widget.kind == 'Task' ||
                  widget.kind == 'Visitor' ||
                  widget.kind == 'Email')
                TextField(
                  controller: _title,
                  autofocus:
                      widget.kind == 'Note' ||
                      widget.kind == 'Document' ||
                      widget.kind == 'Task' ||
                      widget.kind == 'Email',
                  decoration: InputDecoration(
                    labelText: switch (widget.kind) {
                      'Note' => 'Note title',
                      'Visitor' => 'Department / person to visit',
                      'Task' => 'Task title',
                      'Email' => 'Email subject',
                      _ => 'Document title',
                    },
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
              if (widget.kind == 'Enquiry') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Enquiry category',
                  ),
                  items:
                      const [
                            'General enquiry',
                            'Registration',
                            'Accessibility',
                            'Academic support',
                            'Financial aid',
                            'Documents',
                            'Other',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ],
              if (widget.kind == 'Call' || widget.kind == 'Enquiry') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['Low', 'Normal', 'High']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v ?? _priority),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _detail,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: switch (widget.kind) {
                    'Note' => 'Note details',
                    'Call' => 'Reason for call / message',
                    'Appointment' => 'Purpose or additional details',
                    'Enquiry' => 'Request summary',
                    'Visitor' => 'Reason for visit',
                    'Task' => 'Task details or follow-up notes',
                    'Email' => 'Email message draft',
                    _ => 'Document content',
                  },
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
              if (widget.kind == 'Call')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Call-back requested'),
                  value: _callback,
                  onChanged: (v) => setState(() => _callback = v),
                ),
              const SizedBox(height: 9),
              const Text(
                'Windows saves records on this computer. Web and mobile records remain in this session.',
                style: TextStyle(fontSize: 10, color: Color(0xFF708078)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final when = DateTime.now().add(const Duration(days: 1));
    Navigator.pop(
      context,
      _RecordData(
        title: _title.text.trim().isEmpty
            ? (widget.kind == 'Visitor' ? 'Student Support' : widget.kind)
            : _title.text.trim(),
        name: _name.text.trim().isEmpty
            ? widget.kind == 'Visitor'
                  ? 'Walk-in visitor'
                  : widget.kind == 'Email'
                  ? 'Recipient to be confirmed'
                  : 'Walk-in learner'
            : _name.text.trim(),
        phone: _phone.text.trim(),
        detail: _detail.text.trim().isEmpty
            ? 'Details to be added.'
            : _detail.text.trim(),
        priority: _priority,
        callback: _callback,
        category: _category,
        when: DateTime(when.year, when.month, when.day, 10),
        location: _location.text.trim().isEmpty
            ? 'Student Support office'
            : _location.text.trim(),
      ),
    );
  }
}

class _RecordData {
  const _RecordData({
    required this.title,
    required this.name,
    required this.phone,
    required this.detail,
    required this.priority,
    required this.callback,
    required this.category,
    required this.when,
    required this.location,
  });
  final String title, name, phone, detail, priority, category, location;
  final bool callback;
  final DateTime when;
}

class _DestinationMatch {
  const _DestinationMatch(this.choices, this.confidence);
  final List<String> choices;
  final double confidence;
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Appointment {
  const _Appointment(
    this.title,
    this.name,
    this.when,
    this.location,
    this.category,
  );
  final String title, name, location, category;
  final DateTime when;
}

class _Call {
  const _Call(
    this.caller,
    this.phone,
    this.reason,
    this.callback,
    this.priority,
    this.when,
  );
  final String caller, phone, reason, priority;
  final bool callback;
  final DateTime when;
}

class _Note {
  const _Note(this.title, this.body, this.when);
  final String title, body;
  final DateTime when;
}

class _Enquiry {
  const _Enquiry(
    this.name,
    this.category,
    this.detail,
    this.status,
    this.priority,
  );
  final String name, category, detail, status, priority;
}

class _Document {
  const _Document(this.title, this.summary, this.when);
  final String title, summary;
  final DateTime when;
}

class _EmailDraft {
  const _EmailDraft(this.recipient, this.subject, this.body, this.when);
  final String recipient, subject, body;
  final DateTime when;
}

class _Visitor {
  _Visitor(this.name, this.host, this.purpose, this.checkedIn);
  final String name, host, purpose;
  final DateTime checkedIn;
  DateTime? checkedOut;
}

class _ReceptionTask {
  _ReceptionTask(this.title, this.detail, this.created, this.done);
  final String title, detail;
  final DateTime created;
  bool done;
}

class _ChatLine {
  const _ChatLine(this.user, this.text);
  final bool user;
  final String text;
}

class _AssistantResult {
  const _AssistantResult({
    required this.reply,
    required this.action,
    required this.destination,
    required this.fields,
    required this.needsClarification,
    this.transcript = '',
    this.confidence = 0,
  });

  final String reply, action, destination;
  final Map<String, String> fields;
  final bool needsClarification;
  final String transcript;
  final double confidence;

  factory _AssistantResult.fromJson(Map<String, dynamic> json) {
    final raw = json['fields'];
    final fields = <String, String>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String && entry.value is String) {
          fields[entry.key as String] = entry.value as String;
        }
      }
    }
    return _AssistantResult(
      reply: json['reply'] is String
          ? json['reply'] as String
          : 'I am ready to help.',
      action: json['action'] is String ? json['action'] as String : 'clarify',
      destination: json['destination'] is String
          ? json['destination'] as String
          : '',
      fields: fields,
      needsClarification: json['needs_clarification'] == true,
      transcript: json['transcript'] is String
          ? json['transcript'] as String
          : '',
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0,
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
}

String _month(int m) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][m - 1];
String _weekday(DateTime d) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][d.weekday - 1];
