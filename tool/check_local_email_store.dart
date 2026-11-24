import 'dart:io';

import '../lib/data/local_email_draft_store.dart';

Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp(
    'liyabona-email-store-',
  );
  try {
    final store = LocalEmailDraftStore.inDirectory(directory);
    final drafts = <Map<String, Object?>>[
      {
        'recipient': 'Reception Manager',
        'subject': 'Registration follow-up',
        'body': 'A local draft body.',
        'when': DateTime.utc(2026, 11, 25).toIso8601String(),
      },
    ];
    await store.save(drafts);
    final firstRead = await store.load();
    if (firstRead?.single['subject'] != 'Registration follow-up') {
      throw StateError('The saved email draft could not be read back.');
    }

    await store.save([
      ...drafts,
      {...drafts.single, 'subject': 'Second draft'},
    ]);
    final secondRead = await store.load();
    if (secondRead?.length != 2 ||
        secondRead?.last['subject'] != 'Second draft') {
      throw StateError('Replacing the local drafts file failed.');
    }
    print('Local email draft file persistence passed.');
  } finally {
    await directory.delete(recursive: true);
  }
}
