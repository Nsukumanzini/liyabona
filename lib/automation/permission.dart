/// Native operations must be independently validated at the execution boundary.
/// This gate is a foundation; it does not grant native automation capability.
enum AutomationOperation {
  readWindow,
  readFile,
  systemInformation,
  openApp,
  navigate,
  createDraft,
  overwrite,
  delete,
  sendEmail,
  printDocument,
  submitForm,
  exportSensitive,
  closeApp,
  shell,
  elevate,
  credentials,
  securitySettings,
}

class AutomationRequest {
  const AutomationRequest(this.operation, this.target, this.parameters);
  final AutomationOperation operation;
  final String target;
  final Map<String, String> parameters;
  String get identity {
    final keys = parameters.keys.toList()..sort();
    return [
      operation.name,
      target,
      for (final key in keys) '$key=${parameters[key]}',
    ].map((part) => '${part.length}:$part').join();
  }
}

class AutomationPermissions {
  String? _approved;
  static const restricted = {
    AutomationOperation.shell,
    AutomationOperation.elevate,
    AutomationOperation.credentials,
    AutomationOperation.securitySettings,
  };
  static const sensitive = {
    AutomationOperation.overwrite,
    AutomationOperation.delete,
    AutomationOperation.sendEmail,
    AutomationOperation.printDocument,
    AutomationOperation.submitForm,
    AutomationOperation.exportSensitive,
    AutomationOperation.closeApp,
  };
  void approve(AutomationRequest request) {
    if (restricted.contains(request.operation))
      throw StateError('Restricted operation');
    _approved = request.identity;
  }

  void cancel() => _approved = null;
  bool consume(AutomationRequest request) {
    final approved = _approved;
    _approved = null;
    if (restricted.contains(request.operation) || request.target.trim().isEmpty)
      return false;
    return !sensitive.contains(request.operation) ||
        approved == request.identity;
  }
}
