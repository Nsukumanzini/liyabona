# Liyabona Reception

Liyabona is an accessible reception workspace for TVET Student Support Services. It supports Android, iOS, Windows and web, with voice navigation, spoken screen summaries, keyboard and touch controls, larger text and high contrast.

The workspace includes a calendar, learner enquiries, notes, documents, email drafts, learner contacts, campus information, visitor records, tasks and an AI assistant. Reception records are saved locally on Windows and remain in the current session on web and mobile. Student systems and the college mailbox are not connected.

## AI service setup

When a voice session is active and the computer is online, Liyabona sends a short, silence-trimmed audio clip to Google Gemini through Vercel for English (South Africa) transcription and command handling in one request. Gemini returns the transcript, action and a confidence score. The server rejects empty or low-confidence transcripts before the app can perform an action. Audio is held in memory by the app and is not saved as a recording. The Gemini API key stays on Vercel. If the network AI service is unavailable, Liyabona falls back to the device's speech recognizer.

To enable transcription and AI replies, add the Gemini API key in Google AI Studio to the Vercel project as `GEMINI_API_KEY`, then redeploy. Keep the key on Vercel; never put it in Flutter or GitHub. Google AI Studio usage is subject to its current quotas and data terms. Confirm the college's data-handling requirements before sending learner or staff information.

Email drafts can be prepared and reviewed in Liyabona. Sending or receiving college email requires Student Support's mailbox provider and secure access to be approved and configured by college IT.

On Windows, switch to an email, Office document or another app and press **Ctrl+Alt+R**. Liyabona reads aloud text that the active app exposes through Windows UI Automation. This feature is read-only; the extracted text stays on the computer and is not added to chat or sent to Gemini. It can only read content exposed by the other app's accessibility support, and it does not sign in to mailboxes or modify external apps.

The Windows app also shows a small floating microphone button above other apps. Click it, or press **Ctrl+Alt+Space**, to open Liyabona and start a voice session. The microphone is off until activated. Clicking the button again stops the session. On Windows, the optional Assist wake word can be enabled in the AI assistant settings; while enabled, Windows speech recognition listens locally for “Assist” as long as Liyabona is open. Reading text from another app remains a separate, local, read-only shortcut.

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

Start a voice session using **Talk to Liyabona**. After each request, press any key within 15 seconds to keep listening; if no key is pressed, Liyabona stops listening. Opening a screen happens immediately. Before reading information or creating, editing, or deleting a record, press any key within 15 seconds to approve; otherwise the request is cancelled. Say **stop listening** at any time to end the session, or choose **Stop voice**.

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
- “Edit the task called prepare visitor sheets and change the detail to print 20 copies.”
- “Delete the note called registration forms.”
- Press any key within 15 seconds when Liyabona asks to continue listening or approve a change; otherwise the request is cancelled.

The app keeps the microphone off until a voice session is started. Voice commands are processed online when a connection is available, with device speech recognition as the fallback.
