# Release readiness: blocked by critical issues

This working copy is not a final offline Windows AI assistant. Do not deploy it
for unrestricted institutional use. Earlier successful Windows artifacts predate
these changes and do not validate this revision.

## Actual architecture

Flutter reception screens and SharedPreferences records; native Windows floating
control, UI Automation text reading, allowlisted application launch, statically
linked Whisper and Windows speech output. Local keyword Knowledge retrieval and
standalone voice and permission controllers have been added. There is no working
Qwen/llama.cpp integration, SQLite database or complete document intelligence.
The permission controller does not yet enforce native execution boundaries.

## Validation performed

Pure Dart voice interaction, Knowledge retrieval and permission checks passed.
The release gate correctly fails with six critical blockers. git diff --check
passed. Flutter analysis was attempted but failed before analysing the app:
the SDK attempted an unavailable network fetch and a write to a read-only
telemetry directory. Widget tests, Windows compilation, installer generation,
upgrade validation and disconnected-network integration tests were not run.
No new release artifact, checksum or size is available.

## Distribution workflow

`.github/workflows/build-windows.yml` now pins Flutter 3.50.0 and requires
analysis, Flutter tests, deterministic checks and the readiness gate before
compilation and packaging. It remains a development build workflow, not a
complete installer/release pipeline. GitHub Actions dependencies are still tag
references and need immutable pin review. Model/runtime completeness and
licences must be verified before changing the readiness classification.

A successful future run would expose its portable ZIP under Actions > Build
Windows app > selected run > Artifacts > Liyabona-Windows. Current changes have
not been pushed or run on GitHub. No setup installer is generated.

## Pending acceptance and governance

All physical tests in MANUAL_ACCEPTANCE.md remain pending. Measure cold startup,
transcription latency, inference latency, idle and peak working set, and command
success rate on the actual 4 GB Windows laptop. Run a normal working-day trial
with the intended receptionist using NVDA and Narrator, disconnected networking,
Office versions installed at the college, and emergency cancellation. Record
results and failures rather than inferring compatibility from build success.

Full repository history/secret scanning, dependency security review, institutional
permission and retention policy, confidential learner data access controls,
backup recovery and POPIA responsibility review remain outstanding. Offline
processing alone does not establish legal compliance. No production readiness,
Office compatibility or Windows security acceptance is claimed.
