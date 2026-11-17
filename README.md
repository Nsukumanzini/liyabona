# Liyabona Reception

A Flutter front-end demo for a student support receptionist. It targets Android, iOS, Windows and web. It includes a deliberate voice session, screen read-aloud, keyboard and touch controls, large text and high-contrast options, and fictional reception records.

The AI assistant opens first and remains available from the sparkle button on every screen. It can navigate and manage demo records through Vercel AI Gateway. Requests and a short screen summary are sent to Google Gemini. Do not use real learner or staff information in this demo. Records are still held only in memory, and college services are not connected.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

Build the web demo with:

```sh
flutter build web --release
```

Use Android Studio or Xcode to run the mobile targets, and Visual Studio with the Desktop development with C++ workload for Windows.

## Build Windows with GitHub Actions

The workflow at `.github/workflows/build-windows.yml` builds a Windows release on a GitHub-hosted Windows runner and saves `Liyabona-Windows.zip` as an Actions artifact.

1. Open this repository on GitHub and select **Actions**. Approve Actions for the repository if GitHub asks.
2. Select **Build Windows app**, then select **Run workflow**. New pushes to `main` also start a build.
3. Open the completed workflow run and download the **Liyabona-Windows** artifact.
4. Extract the ZIP on the Windows computer and run `liyabona.exe` from the extracted folder. Keep the DLLs and data folders beside the EXE.

GitHub's `windows-latest` runner supplies the Windows build tools, so Visual Studio does not need to be installed on your development computer. The Windows machine still needs a compatible microphone and a locally available speech-recognition language pack for on-device speech recognition. The runner builds the app; it does not test speech recognition on the target computer.

## Voice demo commands

Start a voice session using **Talk to Liyabona**. Say a command, pause while the app responds, then continue speaking. Say **stop listening** to end the session, or tap **Stop voice**.

Examples:

- “Check the calendar.”
- “Read this screen.”
- “Log a call from Alex about a replacement card.”
- “Schedule an appointment with Sam about registration.”
- “Create a note about preparing the orientation packs.”
- “Add to my note: call the transport office.”
- “Create a document about appointment confirmation.”
- “Ask the copilot what needs a call-back.”
- “Find a learner.”
- “Check in visitor Sam visiting the campus manager.”
- “Check out Sam.”
- “Add a desk task: prepare the visitor sign-in sheets.”
- “Complete task prepare the visitor sign-in sheets.”
- “Open the visitor register.”
- “Show my tasks.”
- “Write a note that the registration forms are ready.”
- “Remind me to call the transport office tomorrow.”
- “Schedule a meeting with Lerato tomorrow at 2 PM about registration.”

## Demo limits

Names and records are fictional and held in memory for this session. AI requests use Vercel AI Gateway and Google Gemini; the current screen summary and conversation are sent with each request. No college system, email or persistent database is connected. Web speech recognition depends on browser support and network availability. Native speech recognition tries an installed on-device language pack first and may fall back to the device speech service. The microphone stays off until the user starts a voice session.

