# Liyabona Reception

Liyabona is an accessibility-focused reception workspace for TVET Student Support Services. It includes reception screens for appointments, enquiries, notes, documents, email drafts, learners, visitors, tasks and campus knowledge. The interface supports keyboard navigation, larger text, high contrast, screen reading and voice commands.

> **Release status: Experimental.** Physical testing with the intended receptionist, microphone, NVDA/Narrator, and target college computer is still required. The production release gate remains in place.

## Windows voice and local AI

The Windows voice flow is: activate the microphone, see the locally recognized words appear in the Copilot chat as you speak, then submit the completed transcript to Liyabona’s local AI and validated reception command handler. Windows offline speech recognition is preferred for live transcription; bundled Whisper is the fallback if Windows speech recognition is unavailable. Listening stops after each request. The compact floating assistant can be started with **Ctrl+Alt+Space**; **Ctrl+Alt+R** reads accessible text from the active Windows app. External app reading is local and read-only.

Known reception actions use deterministic command handling. Qwen3 0.6B Q4_K_M runs locally through the bundled llama.cpp CPU runtime for general answers and email composition. Email commands open the Emails screen, save a draft in the current list, and write a local file at:

```text
%LOCALAPPDATA%\Liyabona\email-drafts.json
```

If the local model is unavailable or takes too long to compose an email, Liyabona saves a professional built-in template instead. Drafts are not sent. College mailbox connection and sending are not implemented.

Try voice or text commands such as:

- “Open the calendar.”
- “Create a note about the registration meeting.”
- “Add a task to prepare the welcome packs.”
- “Generate an email to the campus manager about registration.”
- “Show an example of an email draft.”
- “Read the screen.”

The assistant displays the words it recognized before carrying out the request. If it did not hear the instruction correctly, repeat it. Use the microphone button or floating assistant again for the next request.

## Local data and privacy

Windows reception records are stored on the current Windows user’s device. Email drafts are also stored in the Liyabona Local AppData folder above. No Gemini API key or online AI service is required. External applications such as browsers and mail clients may independently require internet access. Do not store passwords or confidential learner information in general notes or prompts without college approval.

## Experimental Windows build

The `development/offline-integration-audit` branch uses the **Experimental Windows validation** workflow. Pushes to that development branch run Flutter analysis, automated tests, local inference checks and a Windows x64 build. The uploaded artifact is named **EXPERIMENTAL-Liyabona-Windows** and includes the local AI runtime and models. It is for testing, not approved for college deployment.

To download it, open the repository’s **Actions** page, select the latest successful **Experimental Windows validation** run for the development branch, and download its artifact. Extract the ZIP and run `liyabona.exe`. Keep the `data`, `ai-runtime` and `speech_models` folders beside the executable. The executable is unsigned; do not bypass Windows security policy. The recent Windows workflow disables AVX and SSE4.2 in the bundled Whisper build for compatibility with older x64 processors.

The separate production workflow still checks the release-readiness gate. Do not publish an experimental artifact as a production release.

## Build locally

Windows compilation requires Flutter 3.50.0, CMake and Visual Studio with the Desktop development with C++ workload. The GitHub Actions Windows runner can build the app when a local Windows development machine is unavailable. Model binaries are downloaded and verified by workflow scripts; they are not committed to Git.

## Physical acceptance checks still required

- Verify voice pickup and South African English transcription with the receptionist’s microphone and room conditions.
- Try short commands and email requests with the microphone, then confirm the recognized words, draft in the Emails screen and local JSON file.
- Test spoken responses, NVDA and Windows Narrator.
- Check startup, memory use, and a normal workday on the college’s lowest-specification computer.
- Confirm the college’s approval for local storage of any institutional information.
