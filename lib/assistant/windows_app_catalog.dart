/// Explicit allowlist of common Windows apps used in reception work.
///
/// Unknown names are intentionally not passed to the operating system. This
/// keeps voice based launching predictable and avoids turning transcripts into
/// arbitrary process launches.
const Map<String, String> _windowsAppAliases = {
  'outlook': 'outlook',
  'microsoft outlook': 'outlook',
  'word': 'word',
  'microsoft word': 'word',
  'excel': 'excel',
  'microsoft excel': 'excel',
  'powerpoint': 'powerpoint',
  'power point': 'powerpoint',
  'microsoft powerpoint': 'powerpoint',
  'teams': 'teams',
  'microsoft teams': 'teams',
  'onenote': 'onenote',
  'one note': 'onenote',
  'microsoft onenote': 'onenote',
  'edge': 'edge',
  'microsoft edge': 'edge',
  'browser': 'edge',
  'web browser': 'edge',
  'chrome': 'chrome',
  'google chrome': 'chrome',
  'chrome browser': 'chrome',
  'google chrome browser': 'chrome',
  'zoom': 'zoom',
  'zoom workplace': 'zoom',
  'notepad': 'notepad',
  'calculator': 'calculator',
  'file explorer': 'file_explorer',
  'explorer': 'file_explorer',
  'adobe reader': 'pdf_reader',
  'adobe acrobat': 'pdf_reader',
  'adobe acrobat reader': 'pdf_reader',
  'pdf reader': 'pdf_reader',
  'photos': 'photos',
  'microsoft photos': 'photos',
};

const Map<String, String> _windowsAppNames = {
  'outlook': 'Outlook',
  'word': 'Word',
  'excel': 'Excel',
  'powerpoint': 'PowerPoint',
  'teams': 'Microsoft Teams',
  'onenote': 'OneNote',
  'edge': 'Microsoft Edge',
  'chrome': 'Google Chrome',
  'zoom': 'Zoom Workplace',
  'notepad': 'Notepad',
  'calculator': 'Calculator',
  'file_explorer': 'File Explorer',
  'pdf_reader': 'Adobe Acrobat Reader',
  'photos': 'Microsoft Photos',
};

/// Returns an approved app ID only for explicit open/launch requests.
String? approvedWindowsAppId(String command) {
  final app = command
      .toLowerCase()
      .trim()
      .replaceFirst(
        RegExp(
          r'^(?:(?:please|can you|could you)\s+)?'
          r'(?:open|launch|start)\s+(?:the\s+)?',
        ),
        '',
      )
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .trim();
  return _windowsAppAliases[app];
}

String windowsAppName(String appId) => _windowsAppNames[appId] ?? 'that app';
