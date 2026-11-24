/// Extractive retrieval only: source text is data and never an executable tool.
class SourceSection {
  const SourceSection(this.source, this.section, this.text);
  final String source;
  final int section;
  final String text;
  String get citation => '$source, section $section';
}

class LocalKnowledge {
  static Set<String> terms(String text) => RegExp(r'[a-z0-9]+')
      .allMatches(text.toLowerCase())
      .map((match) => match[0]!)
      .where(
        (term) =>
            term.length > 2 &&
            !const {
              'the',
              'and',
              'what',
              'about',
              'find',
              'information',
              'for',
              'does',
              'say',
            }.contains(term),
      )
      .toSet();

  static List<SourceSection> chunk(
    String source,
    String text, {
    int maximumCharacters = 900,
  }) {
    if (maximumCharacters < 1) throw ArgumentError.value(maximumCharacters);
    final result = <SourceSection>[];
    var remaining = text.trim();
    while (remaining.isNotEmpty) {
      var end = remaining.length < maximumCharacters
          ? remaining.length
          : maximumCharacters;
      if (end < remaining.length) {
        final boundary = remaining.lastIndexOf(' ', end);
        if (boundary > end ~/ 2) end = boundary;
      }
      result.add(
        SourceSection(
          source,
          result.length + 1,
          remaining.substring(0, end).trim(),
        ),
      );
      remaining = remaining.substring(end).trim();
    }
    return result;
  }

  static List<SourceSection> search(
    String query,
    List<SourceSection> sections, {
    int limit = 3,
    int contextCharacters = 1800,
  }) {
    final requested = terms(query);
    if (requested.isEmpty || limit < 1 || contextCharacters < 1) return [];
    final scored =
        sections
            .map(
              (section) => (
                section: section,
                score: terms(section.text).intersection(requested).length,
              ),
            )
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    final result = <SourceSection>[];
    var budget = contextCharacters;
    for (final item in scored.take(limit)) {
      if (budget <= 0) break;
      final original = item.section;
      final text = original.text.length <= budget
          ? original.text
          : original.text.substring(0, budget);
      result.add(SourceSection(original.source, original.section, text));
      budget -= text.length;
    }
    return result;
  }
}
