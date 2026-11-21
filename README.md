# Liyabona Reception

Liyabona is an accessible reception workspace for TVET Student Support Services. It supports Android, iOS, Windows and web, with voice navigation, spoken screen summaries, keyboard and touch controls, larger text and high contrast.

The workspace includes a calendar, learner enquiries, notes, documents, email drafts, learner contacts, campus information, visitor records, tasks and an AI assistant. Reception records are saved locally on Windows and remain in the current session on web and mobile. Student systems and the college mailbox are not connected.

## AI service setup

When a voice session is active and the computer is online, Liyabona sends a short, silence-trimmed audio clip to Google Gemini through Vercel for English (South Africa) transcription and command handling in one request. Gemini returns the transcript, action and a confidence score. The server rejects empty or low-confidence transcripts before the app can perform an action. Audio is held in memory by the app and is not saved as a recording. The Gemini API key stays on Vercel. If the network AI service is unavailable, Liyabona falls back to the device's speech recognizer.

To enable transcription and AI replies, add the Gemini API key in Google AI Studio to the Vercel project as `GEMINI_API_KEY`, then redeploy. Keep the key on Vercel; never put it in Flutter or GitHub. Google AI Studio usage is subject to its current quotas and data terms. Confirm the college's data-handling requirements before sending learner or staff information.

Email drafts can be prepared and reviewed in Liyabona. Sending or receiving college email requires Student Support's mailbox provider and secure access to be approved and configured by college IT.

On Windows, switch to an email, Office document or another app, activate the floating Liyabona assistant, and say **“read”**, **“read the screen”** or **“ready”**. You can also press **Ctrl+Alt+R**. Liyabona reads aloud text that the active app exposes through Windows UI Automation, in short sections. Say **“continue reading”** for the next section or **“repeat”** to hear the previous section again. Screen reading is read-only; the extracted text stays on the computer and is not added to chat or sent to Gemini. It can only read content exposed by the other app's accessibility support, and it does not sign in to mailboxes or modify external apps.

The Windows app also shows a small floating microphone button above other apps. Click it, or press **Ctrl+Alt+Space**, to start a voice session without restoring the full Liyabona window. The microphone is off until activated. The voice session stops after each request; click the floating button again for another request. On Windows, the optional Assist wake word can be enabled in the AI assistant settings; while enabled, Windows speech recognition listens locally for “Assist” as long as Liyabona is open. Reading text from another app remains a separate, local, read-only shortcut.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

Build the web application with:

```sh
flutter build web --release
```

Vercel uses `scripts/vercel-build.sh` to install Flutter 3.50.0 and build the web application from the connected Git repository. The static site is published from `build/web`, while `api/assistant.js` runs as a Vercel function.

Use Android Studio or Xcode for the mobile targets. A local Windows build requires Visual Studio with the Desktop development with C++ workload.

## Build Windows with GitHub Actions

The workflow at `.github/workflows/build-windows.yml` builds a Windows release on a GitHub-hosted Windows runner and saves `Liyabona-Windows.zip` as an Actions artifact.

1. Open the repository on GitHub and select **Actions**. Approve Actions for the repository if GitHub asks.
2. Select **Build Windows app**, then **Run workflow**. A push to `main` also starts a build.
3. Open the completed workflow run and download the **Liyabona-Windows** artifact.
4. Extract the ZIP on Windows and run `liyabona.exe`. Keep the DLLs and `data` folder beside the executable.

The GitHub runner supplies the Windows build tools, so Visual Studio is not needed on the development computer. The target Windows computer needs microphone access and a supported speech recognizer. The runner compiles the application but cannot verify microphone operation on that computer. The distributed executable is not code-signed; Windows security policy may require approval from the computer administrator or a trusted signature.

## Voice commands

Start a voice session using **Talk to Liyabona**. Liyabona stops listening after each request. Open a screen, create a note or task, draft an email, or ask a reception question; repeat the voice activation for another request. If Gemini is unavailable or does not transcribe promptly, Windows switches to its built-in speech recognition for the current request. If Liyabona cannot make out the words, it says “Repeat again.”

Online voice recognition sends a short recording to Gemini, which transcribes English (South Africa) and interprets the command in one request. If the online service is unreachable, Windows uses its installed speech recognizer. Voice-created, edited and deleted notes, tasks, appointments, email drafts, call logs, enquiries, visitor records and documents are saved in the Windows user's local app storage. The Knowledge screen lets the receptionist type or paste personal preferences and helpful work information. Saved Knowledge is sent to Gemini with an AI request; do not enter passwords or confidential learner details.

Examples:

- “Open calendar.”
- “Schedule an appointment with Lerato tomorrow at 2 PM about registration.”
- “Create a note that the registration forms are ready.”
- “Add a task to prepare the visitor sign-in sheets.”
- “Remind me to call the transport office tomorrow.”
- “Show my tasks.”
- “Complete task prepare the visitor sign-in sheets.”
- “Draft an email to Amina about financial aid.”
- “Read this screen.”
- “Continue reading.”
- “Repeat.”
- “Edit the task called prepare visitor sheets and change the detail to print 20 copies.”
- “Delete the note called registration forms.”
- The app speaks “Hello, I hope you are doing well” when it opens.

The app keeps the microphone off until a voice session is started, unless the optional Windows Assist wake word is enabled. Voice commands use Gemini online when available and switch to device speech recognition if the audio transcription takes more than eight seconds or the service is unavailable.
