import '../lib/automation/permission.dart';
void main() {
  final gate = AutomationPermissions();
  const delete = AutomationRequest(AutomationOperation.delete, 'note:1', {});
  const other = AutomationRequest(AutomationOperation.delete, 'note:2', {});
  if (gate.consume(delete)) throw StateError('Unapproved deletion');
  gate.approve(delete);
  if (gate.consume(other)) throw StateError('Approval changed target');
  gate.approve(delete);
  if (!gate.consume(delete) || gate.consume(delete)) throw StateError('Approval reuse');
  gate.approve(delete); gate.cancel();
  if (gate.consume(delete)) throw StateError('Cancelled approval');
  for (final operation in AutomationPermissions.restricted) {
    if (gate.consume(AutomationRequest(operation, 'computer', {}))) throw StateError('Restricted allowed');
  }
  print('Permission gate checks passed (pure Dart, no native execution).');
}
