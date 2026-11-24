import '../lib/assistant/command_matching.dart';

void main() {
  assert(!containsCommandPhrase('show an email draft', 'ai'));
  assert(containsCommandPhrase('open email drafts', 'email drafts'));
  assert(!containsCommandPhrase('open the calendar', 'email drafts'));

  assert(
    isEmailDraftRequest(
      'draft an email to the campus manager about registration',
      createIntent: true,
    ),
  );
  assert(
    isEmailDraftRequest(
      'show an example of an email draft',
      createIntent: false,
    ),
  );
  assert(
    !isEmailDraftRequest('open the email drafts screen', createIntent: false),
  );
  print('Command matching passed.');
}
