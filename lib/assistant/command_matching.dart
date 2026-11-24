/// Small deterministic checks shared by typed and transcribed voice requests.
/// These checks deliberately match whole words so `ai` cannot match `email`.
bool containsCommandPhrase(String text, String phrase) {
  final escaped = RegExp.escape(phrase.trim().toLowerCase());
  if (escaped.isEmpty) return false;
  return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)')
      .hasMatch(text.toLowerCase());
}

bool isEmailDraftRequest(String command, {required bool createIntent}) {
  if (!containsCommandPhrase(command, 'email') &&
      !containsCommandPhrase(command, 'e-mail')) {
    return false;
  }
  final asksForExample =
      containsCommandPhrase(command, 'example') ||
      containsCommandPhrase(command, 'sample');
  return createIntent || asksForExample;
}
