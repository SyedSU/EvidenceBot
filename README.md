# EvidenceBot
A device assistant activated by its name. It would use local models to answer questions, open apps, and perform supported device actions with user-granted permissions.

## Native engineering milestone (Godot 4.7.2)

This repository now contains a runnable native assistant at `native/project.godot`. It implements **typed** name activation, session-scoped explicit permission switches, local OpenAI-compatible Q&A, and separately confirmed Windows Calculator / Notepad launch intents. It does not implement voice wake. This is an engineering milestone, not an accepted packaged release; the original device-assistant scope remains required.

Build the reviewed first-party save extension with `python scripts/build_save_adapter.py`, then open `native/project.godot` in Godot **4.7.2** or run `godot --path native`. A C compiler is build-time only. Missing native persistence blocks actions rather than falling back to unsafe saving. The engine and compiled libraries are not committed.

Type `EvidenceBot` and activate. Opt in to local Q&A, enter an explicit model identifier and port, and run your own compatible server on `127.0.0.1`. Requests go only to the literal loopback address, without authentication tokens, redirects, tools or cloud fallback; timeout 20 seconds, question limit 4,000 characters, response body limit 64 KiB, displayed answer limit 32,768 characters, maximum 512 generated tokens. The server's own configuration determines whether it uses a local model; this client cannot attest that a separately operated server does not proxy elsewhere. Questions and answers are not persisted. Model output is plain untrusted text and is never interpreted as an app action.

On Windows, opt in to app permission, choose a preview and explicitly confirm that one app. The reviewed executable allowlist is `C:/Windows/System32/calc.exe` and `C:/Windows/System32/notepad.exe`, with no arguments or shell. Other Windows installations may safely fail. Each preview uses an unpredictable, one-use capability bound to its app. Cancellation, revocation and restart invalidate pending capabilities. A durable confirmed-attempt record precedes dispatch; interrupted attempts are never retried automatically. A launch request is not proof an app completed or appeared. Windows execution has **not** been validated in this Linux session.

State lives in Godot's separate `EvidenceBot` user directory as inspectable JSON with a previous-generation `.backup`. Audit records contain action/permission metadata and UTC times, not prompt/answer content or credentials. Permissions reset off every session. The UI displays and exports audit JSON to `audit-export.json` in that directory. JSON exports are ordinary user-readable files. Saves use the reviewed Genesis C/GDScript persistence adapter, native locking, checked staged writes, backup and stale-writer rejection. Corrupt files are preserved and block actions. To recover, close instances, preserve originals, and manually restore a known-good `.backup`; there is no automatic pending-action execution. The audit is local and editable by the device owner, not tamper-proof. Audit capacity is bounded to 2,000 events; exhaustion blocks further actions until a future reviewed archive workflow exists.

## Required scope still blocked

- Gmail and Calendar OAuth, secure OS token storage, provider authorization and confirmed send/insert flows require real reviewed client credentials and provider integration. No connection, mail send or event insertion is implemented or represented as successful.
- Android opt-in accessibility requires a real service, device permission and device validation. No service or device actions are implemented.
- Voice activation, Windows execution validation, touch/device acceptance, accessibility review, signed release packaging and target-device performance remain unaccepted. The native UI provides clear unavailable status for provider/device capabilities.

These are required programme deliverables, not removed scope. There are no fake provider tokens, connection badges, sent messages, events or accessibility results.

## Verification

`python scripts/test_native.py /path/to/Godot_v4.7.2-stable_linux.x86_64` runs all four native suites. The Python standard-library server is an explicitly synthetic loopback fixture, and app dispatch tests use a synthetic callable. Tests never open Windows apps or contact Gmail/Calendar/devices.

The 2026-10-23 Linux session passed: activation; explicit permission and app-bound confirmation; replay rejection; revocation; canceled late answer rejection; restart with no executable pending actions; stale writer rejection; corrupt preservation/blocking; native scene startup/platform guard; real HTTP loopback fixture proving malicious answer text remains plain text. A native headless main-scene startup also passed. These do not constitute Windows/device/provider acceptance.

Copied persistence provenance: exact first-party files from EvidenceGenesis `c6a172a` (`native/durability/*`, `native/durability.gdextension`, `native/scripts/save_files.gd`, `scripts/build_save_adapter.py`). The pinned Godot ABI header hash and retained MIT notice remain in the build script and `native/durability`; no new runtime framework or third-party binding was adopted.
