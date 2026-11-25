# Liyabona Reception

Liyabona is an accessibility-focused reception workspace for TVET Student Support Services. It includes reception screens for appointments, enquiries, notes, documents, email drafts, learners, visitors, tasks and campus knowledge. The interface supports keyboard navigation, larger text, high contrast, screen reading and voice commands.

> **Release status: Experimental.** Physical testing with the intended receptionist, microphone, NVDA/Narrator, and target college computer is still required. The production release gate remains in place.

## Windows voice and local AI

On Windows, Liyabona opens Windows Voice Access when it starts (if Voice Access is not already running), focuses the Copilot message box, and does not capture microphone audio itself. Set Voice Access to **Dictation mode** before speaking. In Dictation mode, Windows types speech into the focused message box instead of interpreting it as commands to open or control other apps. Liyabona sends the text after **3 seconds without new typing**; pressing **Enter** or **Send** still sends immediately. The floating assistant and **Ctrl+Alt+Space** bring Voice Access back to the message box. **Ctrl+Alt+R** reads accessible text from the active Windows app; external app reading is local and read-only.

Voice Access must already be configured in Windows, including its language files and microphone. On the first launch, complete any Voice Access setup prompt, return to Liyabona, then use its Voice Access button to refocus the message box. Liyabona launches `VoiceAccess.exe` directly instead of sending a toggle shortcut on startup. Once Liyabona has accepted a request and verified that it completed, it uses **Alt+Shift+B** to put Voice Access to sleep while it speaks the result, then wakes it again. Unclear requests, clarifications and failed operations do not trigger this handoff. If the Voice Access session is not running or its state is unknown, Liyabona leaves it alone. If Voice Access is asleep before dictation, wake it using its own controls. To avoid Voice Access executing an app command, use **Dictation mode** while Liyabona is listening. Liyabona's 3-second idle submit also applies to text typed manually into the Copilot box on Windows.

Known reception actions use deterministic command handling. Qwen3 0.6B Q4_K_M runs locally through the bundled llama.cpp CPU runtime for general answers and email composition. Email commands open the Emails screen, save a draft in the current list, and write a local file at:

```text
%LOCALAPPDATA%\Liyabona\email-drafts.json
```

If the local model is unavailable or takes too long to compose an email, Liyabona saves a professional built-in template instead. Drafts are not sent. College mailbox connection and sending are not implemented.

On Windows, Liyabona can draft content with the local model and ask installed
Microsoft Office applications to save it. Word drafts are saved as `.docx` and
PowerPoint drafts as `.pptx` under `%LOCALAPPDATA%\Liyabona\Documents`; new
filenames are chosen so existing documents are not overwritten. The files open
in the corresponding Office application. Email drafts are stored locally in
Liyabona's Emails screen and are not sent. Say “write an essay about student
success in Word,” “create a PowerPoint presentation about registration,” or
“draft an email to the campus manager about the meeting.” Local model output
should be reviewed before institutional use. These Office actions require the
corresponding desktop Office application to be installed and available.

Say “search the web for student funding in Edge” to open a Bing search in Edge.
That action uses the internet only because web search itself is online; it does
not send the query to Liyabona's local AI service.

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
- “Write an essay about student success in Word.”
- “Create a PowerPoint presentation about registration.”
- “Search the web for student funding in Edge.”
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
