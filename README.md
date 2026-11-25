# Liyabona Reception

Liyabona is an accessibility-focused reception workspace for TVET Student Support Services. It includes reception screens for appointments, enquiries, notes, documents, email drafts, learners, visitors, tasks and campus knowledge. The interface supports keyboard navigation, larger text, high contrast, screen reading and voice commands.

> **Release status: Experimental.** Physical testing with the intended receptionist, microphone, NVDA/Narrator, and target college computer is still required. The production release gate remains in place.

## Windows voice and local AI

On Windows, Liyabona opens Windows Voice Access when it starts (if Voice Access is not already running), focuses the Copilot message box, and does not capture microphone audio itself. Set Voice Access to **Dictation mode** before speaking. In Dictation mode, Windows types speech into the focused message box instead of interpreting it as commands to open or control other apps. Liyabona sends the text after **3 seconds without new typing**; pressing **Enter** or **Send** still sends immediately. The floating assistant and **Ctrl+Alt+Space** bring Voice Access back to the message box. **Ctrl+Alt+R** reads accessible text from the active Windows app; external app reading is local and read-only.

Voice Access must already be configured in Windows, including its language files and microphone. On the first launch, complete any Voice Access setup prompt, return to Liyabona, then use its Voice Access button to refocus the message box. Liyabona launches `VoiceAccess.exe` directly instead of sending a toggle shortcut, so it will not accidentally switch off a Voice Access session that is already open. If Voice Access is running but asleep or its microphone is off, wake or unmute it using its own controls. Microsoft documents **Alt+Shift+B** to toggle between listening and sleep; Liyabona does not send that toggle because it cannot safely infer the current microphone state. To avoid Voice Access executing a spoken app command, say **“Dictation mode”** when Voice Access is active. Liyabona's 3-second idle submit also applies to text typed manually into the Copilot box on Windows.

Known reception actions use deterministic command handling. Qwen3 0.6B Q4_K_M runs locally through the bundled llama.cpp CPU runtime for general answers and email composition. Email commands open the Emails screen, save a draft in the current list, and write a local file at:

```text
%LOCALAPPDATA%\Liyabona\email-drafts.json
```

If the local model is unavailable or takes too long to compose an email, Liyabona saves a professional built-in template instead. Drafts are not sent. College mailbox connection and sending are not implemented.

On Windows, the approved app launcher also supports Microsoft Teams, OneNote,
Google Chrome, Zoom Workplace, Adobe Acrobat Reader and Microsoft Photos, in addition to the
Office apps and Windows utilities. Availability depends on the app being
installed and its Windows app registration being intact. Unknown app names are
not passed to Windows as process commands. Reading another app remains
read-only.

Try voice or text commands such as:

- “Open the calendar.”
- “Create a note about the registration meeting.”
- “Add a task to prepare the welcome packs.”
- “Generate an email to the campus manager about registration.”
- “Show an example of an email draft.”
- “Read the screen.”
- “Open Microsoft Teams.”
- “Open OneNote.”
- “Open Adobe Acrobat Reader.”
- “Open Zoom.”

On Windows, dictated or typed words are sent after the composer has been idle for three seconds; use **Enter** or **Send** to submit immediately. On other platforms, review or edit the transcript and press **Enter** or **Send** manually.

## Local data and privacy

Windows reception records are stored on the current Windows user’s device. Email drafts are also stored in the Liyabona Local AppData folder above. No Gemini API key or online AI service is required. External applications such as browsers and mail clients may independently require internet access. Do not store passwords or confidential learner information in general notes or prompts without college approval.

## Experimental Windows build

The `development/offline-integration-audit` branch uses the **Experimental Windows validation** workflow. Pushes to that development branch run Flutter analysis, automated tests, local inference checks and a Windows x64 build. The uploaded artifact is named **EXPERIMENTAL-Liyabona-Windows** and includes the local AI runtime and models. It is for testing, not approved for college deployment.

To download it, open the repository’s **Actions** page, select the latest successful **Experimental Windows validation** run for the development branch, and download its artifact. Extract the ZIP and run `liyabona.exe`. Keep the `data`, `ai-runtime` and `speech_models` folders beside the executable. The executable is unsigned; do not bypass Windows security policy. The recent Windows workflow disables AVX and SSE4.2 in the bundled Whisper build for compatibility with older x64 processors.

The separate production workflow still checks the release-readiness gate. Do not publish an experimental artifact as a production release.

## Build locally

Windows compilation requires Flutter 3.50.0, CMake and Visual Studio with the Desktop development with C++ workload. The GitHub Actions Windows runner can build the app when a local Windows development machine is unavailable. Model binaries are downloaded and verified by workflow scripts; they are not committed to Git.

## Physical acceptance checks still required

- Confirm Windows Voice Access opens on Liyabona startup and the Copilot message box receives focus.
- Set Voice Access to Dictation mode; speak a request and verify the words are typed before Liyabona submits them after three idle seconds.
- Confirm Voice Access does not open applications while in Dictation mode, then verify Liyabona handles typed requests and saves email drafts locally.
- Test with the actual microphone, room acoustics, South African English speech, NVDA and Windows Narrator.
- Test spoken responses, NVDA and Windows Narrator.
- Check startup, memory use, and a normal workday on the college’s lowest-specification computer.
- Confirm the college’s approval for local storage of any institutional information.
