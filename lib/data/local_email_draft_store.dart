import 'dart:convert';
import 'dart:io';

/// A user-scoped, offline JSON file for email drafts on Windows.
class LocalEmailDraftStore {
  LocalEmailDraftStore.inDirectory(Directory directory)
    : file = File(
        '${directory.path}${Platform.pathSeparator}email-drafts.json',
      );

  factory LocalEmailDraftStore.forWindowsUser() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      throw StateError('Windows Local AppData is unavailable.');
    }
    return LocalEmailDraftStore.inDirectory(
      Directory('$localAppData${Platform.pathSeparator}Liyabona'),
    );
  }

  final File file;

  Future<void> save(List<Map<String, Object?>> drafts) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(drafts), flush: true);
    await temporary.rename(file.path);
  }

  Future<List<Map<String, dynamic>>?> load() async {
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    if (value is! List) {
      throw const FormatException('Email draft file must contain a list.');
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
