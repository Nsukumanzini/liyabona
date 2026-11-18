# Liyabona Reception

Liyabona is an accessible reception workspace for TVET Student Support Services. It supports Android, iOS, Windows and web, with voice navigation, spoken screen summaries, keyboard and touch controls, larger text and high contrast.

The workspace includes a calendar, learner enquiries, notes, documents, email drafts, learner contacts, campus information, visitor records, tasks and an AI assistant. Reception records are saved locally on Windows and remain in the current session on web and mobile. Student systems and the college mailbox are not connected.

## AI service setup

Liyabona sends AI requests to Google's Gemini API through a small Vercel server endpoint. Windows speech recognition runs on the computer; recognized requests and screen context are sent to Google when a network connection is available. Built-in reception commands remain available if the AI service cannot respond.

To enable AI replies, create a Gemini API key in Google AI Studio and add it to the Vercel project as the `GEMINI_API_KEY` environment variable, then redeploy the Vercel project. Keep the key on Vercel; never put it in Flutter or GitHub. Google lists a free tier for Gemini 2.5 Flash-Lite subject to usage limits. Google may use data sent through its free tier to improve its products. Confirm the college's data-handling requirements before entering learner or staff information.

Email drafts can be prepared and reviewed in Liyabona. Sending or receiving college email requires Student Support's mailbox provider and secure access to be approved and configured by college IT.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

Build the web application with:

```sh
flutter build web --release
```

Use Android Studio or Xcode for the mobile targets. A local Windows build requires Visual Studio with the Desktop development with C++ workload.

## Build Windows with GitHub Actions

The workflow at `.github/workflows/build-windows.yml` builds a Windows release on a GitHub-hosted Windows runner and saves `Liyabona-Windows.zip` as an Actions artifact.

1. Open the repository on GitHub and select **Actions**. Approve Actions for the repository if GitHub asks.
2. Select **Build Windows app**, then **Run workflow**. A push to `main` also starts a build.
3. Open the completed workflow run and download the **Liyabona-Windows** artifact.
4. Extract the ZIP on Windows and run `liyabona.exe`. Keep the DLLs and `data` folder beside the executable.

The GitHub runner supplies the Windows build tools, so Visual Studio is not needed on the development computer. The target Windows computer needs microphone access and a supported speech recognizer. The runner compiles the application but cannot verify microphone operation on that computer. The distributed executable is not code-signed; Windows security policy may require approval from the computer administrator or a trusted signature.

## Voice commands

Start a voice session using **Talk to Liyabona**. Say a request, pause while Liyabona responds, then continue. Say **stop listening** to end the session, or choose **Stop voice**.

On Windows, voice recognition uses Windows SAPI and prefers English (South Africa) when that recognizer is installed. Otherwise, it uses another installed English recognizer. Recognition is performed on the computer; AI interpretation requires an internet connection. Voice-created notes, tasks, appointments, email drafts, call logs, enquiries, visitor records and documents are saved in the Windows user's local app storage.

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

The app keeps the microphone off until a voice session is started. Web speech recognition depends on browser support and network availability.
