# Windows receptionist acceptance checks — not yet performed

Use a copy of the receptionist's records, with Wi-Fi disconnected and Ethernet
unplugged. Do not regard build success as evidence that these checks passed.

- Launch using only the keyboard. Verify the greeting and readable focus.
- With Narrator, then NVDA, navigate each workspace screen and form. Check
  labels, validation announcements, modal focus and escape/cancellation.
- Activate while minimised using Ctrl+Alt+Space. Read another app using
  Ctrl+Alt+R; ensure no external records change.
- Speak South African English names and campus terms in quiet and ordinary
  office noise. Record expected and actual text manually, without storing audio.
- Try silence, very quiet speech, incomplete requests, unplugged microphone,
  missing model and corrupt model. Check concise spoken recovery.
- Try calendar, notes, tasks, visitors, learner enquiries, documents, Knowledge,
  email drafts and settings. Check the actual record after every mutation.
- Decline a delete confirmation. Check that the record is unchanged.
- Interrupt speech and cancel a request. Check that cancelled work cannot execute
  later and the assistant cannot interpret its own voice as a command.
- Verify Assist activation if installed SAPI recognition supports it. Disable it
  and verify keyboard activation still works.
- Measure startup, transcription latency and peak RAM on the actual 4 GB laptop.
- Repeat with headphones, high contrast and enlarged text.

Local Qwen conversation, spoken confirmation, slot filling, voice microphone
selection and a complete interaction state machine remain implementation gaps.
