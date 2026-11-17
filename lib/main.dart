Warning: truncated output (original token count: 48246)
Total output lines: 5868

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
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

void main() => runApp(const ReceptionDemo());

class ReceptionDemo extends StatefulWidget {
  const ReceptionDemo({super.key});
  @override
  State<ReceptionDemo> createState() => _ReceptionDemoState();
}

class _ReceptionDemoState extends State<ReceptionDemo> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  Future<void> _offlineDataReady = Future<void>.value();
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
  String _lastSpeechText = '';
  int _speechGeneration = 0;
  StateSetter? _popupRebuild;
  String _transcript = '';
  String _heardPhrase = '';
  String _interpretation = '';
  double? _matchConfidence;
  List<String> _pendingChoices = [];
  String _page = 'AI copilot';
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
        'Sample visitor',
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
      // Keep the app usable with its sample records if the local data is damaged.
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
    _listenRestartTimer?.cancel();
    _speech.stop();
    _tts.stop();
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

  void _stopSpeaking() {
    _speechGeneration++;
    _ttsSpeaking = false;
    unawaited(_tts.stop());
    _refreshAssistantPopup();
  }

  void _refreshAssistantPopup() {
    final rebuild = _popupRebuild;
    if (rebuild == null || !mounted) return;
    try {
      rebuild(() {});
    } catch (_) {
      _popupRebuild = null;
    }
  }

  Future<_AssistantResult?> _askModel(String text) async {
    try {
      final history = _chat.toList();
      if (history.isNotEmpty &&
          history.last.user &&
          history.last.text == text) {
        history.removeLast();
      }
      final response = await http
          .post(
            Uri.parse(_assistantEndpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'screen': _page,
              'summary': _pageSummary(),
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
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final code = body is Map ? body['gatewayCode'] : null;
        _assistantError = code == 'customer_verification_required'
            ? 'Vercel AI Gateway needs a valid payment method before it can serve this model.'
            : body is Map && body['error'] is String
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
        _go('Tasks');
        break;
      default:
        break;
    }
  }

  Future<void> _askCopilot(String question) async {
    if (_assistantBusy || question.trim().isEmpty) return;
    if (_isWindowsDesktop) {
      await _offlineDataReady;
      setState(() => _assistantBusy = true);
      await _handleVoiceCommand(
        question,
        consultAi: false,
        resumeVoice: false,
        speakResponse: true,
      );
      if (mounted) setState(() => _assistantBusy = false);
      return;
    }
    if (_voiceSession) {
      await _speech.stop();
      _listening = false;
    }
    _chat.add(_ChatLine(true, question));
    setState(() => _assistantBusy = true);
    _refreshAssistantPopup();
    final result = await _askModel(question);
    String answer;
    if (result != null) {
      _applyAssistantAction(result);
      answer = result.reply;
    } else {
      await _handleVoiceCommand(
        question,
        consultAi: false,
        resumeVoice: false,
        speakResponse: false,
      );
      final transcript = _transcript.split('\n');
      answer =
          'AI is temporarily unavailable. I used the built-in command helper instead. ${transcript.length > 1 ? transcript.skip(1).join(' ') : _answerLocally(question)}';
    }
    _chat.add(_ChatLine(false, answer));
    if (mounted) setState(() => _assistantBusy = false);
    _refreshAssistantPopup();
    await _speak(answer);
  }

  Future<void> _toggleVoice({bool greet = false}) async {
    if (_voiceSession || _listening) {
      _voiceSession = false;
      _processing = false;
      _listenRestartTimer?.cancel();
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
    _listenFailures = 0;
    if (_isWindowsDesktop) await _offlineDataReady;
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
      _assistantError = _isWindowsDesktop
          ? 'Windows offline speech recognition is unavailable. Check Windows speech settings and microphone access.'
          : 'Speech recognition is unavailable. Check microphone permission and the device speech service.';
      if (greet) await _speak('Hello, how can I help you today?');
      _refreshAssistantPopup();
      return;
    }
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
            'This computer does not have offline South African English recognition. Using $selectedName instead.';
      } else {
        _assistantError = '';
      }
    } catch (_) {
      // Let the device choose its default locale if the list is unavailable.
      _speechLocale = null;
    }
    setState(() {
      _voiceSession = true;
      _transcript = _isWindowsDesktop
          ? 'Listening offline on this computer'
          : 'Listening';
    });
    _refreshAssistantPopup();
    if (greet) {
      // Start speech recognition inside the tap gesture. Some browsers reject
      // microphone startup if it is delayed until after the spoken greeting.
      _greetingPlaying = true;
      await _listenOnce();
      await _speak('Hello, how can I help you today?');
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      _greetingPlaying = false;
      if (_voiceSession && !_listening) await _listenOnce();
      return;
    }
    await _listenOnce();
  }

  Future<void> _listenOnce() async {
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
            unawaited(_handleVoiceCommand(heard));
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
      if (stopCommand) _voiceSession = false;
      _processing = false;
      if (mounted) {
        setState(() {
          _listening = false;
          _transcript = stopCommand ? 'Voice assistant stopped.' : 'Okay.';
        });
      }
      _refreshAssistantPopup();
      if (!stopCommand && resumeVoice && _voiceSession && mounted) {
        await _listenOnce();
      }
      return;
    }
    _heardPhrase = phrase;
    _interpretation = 'Checking your request with Liyabona AI';
    _matchConfidence = null;
    if (consultAi) {
      await _speech.stop();
      _listening = false;
      final result = await _askModel(phrase);
      if (result != null &&
          result.action != 'answer' &&
          result.action != 'clarify') {
        _applyAssistantAction(result);
        _chat.add(_ChatLine(true, phrase));
        _chat.add(_ChatLine(false, result.reply));
        _pendingChoices = [];
        _interpretation = result.action == 'navigate'
            ? 'Opening ${result.destination}'
            : result.action == 'clarify'
            ? 'AI needs one more detail'
            : 'AI action: ${result.action.replaceAll('_', ' ')}';
        _matchConfidence = null;
        if (mounted) {
          setState(() {
            _transcript = '“$phrase”\n${result.reply}';
            _listening = false;
          });
        }
        _refreshAssistantPopup();
        if (speakResponse) await _speak(result.reply);
        _processing = false;
        _refreshAssistantPopup();
        if (resumeVoice && _voiceSession && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          await _listenOnce();
        }
        return;
      }
      if (result != null) {
        // The AI heard the request but could not turn it into an app action.
        // Give the built-in command handler the same recognized words before
        // falling back to the AI's spoken answer or clarification.
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
          await Future<void>.delayed(const Duration(milliseconds: 350));
          await _listenOnce();
        }
        return;
      }
    }
    var response =
        'I heard $phrase. Say help to hear some commands I understand.';
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
        response = 'Okay, opening $selection. ${_summaryFor(selection)}';
      }
    } else if (command.contains('stop listening') ||
        command.contains('stop voice') ||
        command.contains('close voice session')) {
      _voiceSession = false;
      _listening = false;
      response = 'Voice session ended.';
    } else if (command.contains('help') ||
        command.contains('what can you do')) {
      response = 'You can say: open calendar, open emails, create a note, add a task, remind me to call someone, show my tasks, complete a task, schedule an appointment, draft an email, check in or check out a visitor, log a call, read this screen, or ask about reception hours.';
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
            'I understood that as $destination. ${_summaryFor(destination)}';
      } else {
        _interpretation = 'I could not match that to a screen';
        _matchConfidence = .2;
        response =
            'I heard “$phrase”, but I could not match it to a screen. Say help to hear available screens.';
      }
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
        _Document(
          title,
          'Draft created in the demo workspace.',
          DateTime.now(),
        ),
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
      response = 'I opened the learner directory. It contains fictional sample records for this demo.';
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
            'There are ${_enquiries.length} sample enquiries: ${_enquiries.map((item) => '${item.name}, ${item.category}, ${item.status}').join('. ')}';
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
          'You have ${_notes.length} saved demo notes. ' +
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
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _listenOnce();
    }
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
                    'Choose the college mailbox and email service. This demo only saves your selection on this device; it does not sign in or connect.',
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
                      )…18246 tokens truncated…11,
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
              'Saved in this demo session',
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
                            : '$mailboxProvider · setup details saved for this demo',
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
              'Email connection needs the college to confirm its mail provider and approve secure access. No mailbox is connected in this demo.',
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
              'Review AI-assisted replies before sending. Drafts stay in this demo session.',
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
          subtitle: 'Sample contacts only. Use fictional records for this presentation.',
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

class _KnowledgePage extends StatelessWidget {
  const _KnowledgePage();
  @override
  Widget build(BuildContext context) => const _PageScroll(
    children: [
      _PageHeading(
        title: 'Reception knowledge',
        subtitle: 'A quick reference for common campus questions. Sample information for discussion only.',
      ),
      _KnowledgeCard(
        icon: Icons.access_time_rounded,
        title: 'Office hours',
        body: 'Monday to Friday, 08:00–16:00. Closed on public holidays.',
      ),
      SizedBox(height: 10),
      _KnowledgeCard(
        icon: Icons.location_on_outlined,
        title: 'Find Student Support',
        body: 'Main block, ground floor, next to the library. Ask reception if you need directions.',
      ),
      SizedBox(height: 10),
      _KnowledgeCard(
        icon: Icons.assignment_outlined,
        title: 'Learner support requests',
        body: 'Record the learner’s request, preferred contact method and any agreed follow-up. Only collect details needed to assist.',
      ),
      SizedBox(height: 10),
      _KnowledgeCard(
        icon: Icons.accessible_forward_rounded,
        title: 'Accessibility support',
        body: 'Ask the learner what support works best for them. Confirm accessible routes and arrange a private meeting when requested.',
      ),
      SizedBox(height: 18),
      _LocalNotice(),
    ],
  );
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
    required this.onVoice,
    required this.onSpeak,
  });
  final List<_ChatLine> chat;
  final Future<void> Function(String) onAsk;
  final bool busy;
  final String error;
  final bool listening;
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
              'The assistant can open screens and manage demo notes, tasks, calls, appointments, visitor check-ins and enquiries. It asks a follow-up when key details are unclear.',
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
          ],
        ),
      ),
      const SizedBox(height: 14),
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
        subtitle: 'Explore the other areas of the demo.',
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
        ('Learners', Icons.people_alt_outlined, 'Fictional learner directory'),
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
                'Demo only: this record stays in memory for this presentation.',
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
  });

  final String reply, action, destination;
  final Map<String, String> fields;
  final bool needsClarification;

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
