import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final file = File('release/readiness.json');
  try {
    final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final blockers = report['criticalBlockers'];
    if (report['schemaVersion'] != 1 || blockers is! List ||
        report['classification'] != 'ready_for_physical_acceptance_testing' ||
        blockers.isNotEmpty) {
      stderr.writeln('Release blocked: critical integrations or validation are incomplete.');
      if (blockers is List) {
        for (final blocker in blockers) { stderr.writeln('- $blocker'); }
      }
      exitCode = 1;
      return;
    }
    stdout.writeln('Candidate gate passed. Physical acceptance is still required.');
  } catch (_) {
    stderr.writeln('Release blocked: missing or invalid readiness report.');
    exitCode = 1;
  }
}
