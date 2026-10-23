# Desktop Google source engineering — 2026-10-23

Live provider acceptance **UNRUN**. No actual Google credentials, authorization browser, Google network calls, Gmail messages or Calendar events were used in development/tests. Owner desktop OAuth client and authorized account remain required. Android OAuth/accessibility/voice and device/package/signing acceptance remain unimplemented/unaccepted as described in README.

Actual command: `GODOT=/workspace/work/save-safety/engine/Godot_v4.7.2-stable_linux.x86_64 sh scripts/run_tests.sh`. Native save extension rebuilt; isolated source harness imported editor assets, ran six suites with separate user directories, then main-scene startup. Full output: `native-suite.log`. Diff whitespace check passed. No new dependencies.

Test-first failures observed for missing protocol/provider scripts, missing UI members, recipient control validation, cancellation API and oversized RFC2047 encoded word. Production fixes followed those failures. Pure protocol vector/callback/payload tests and injected synthetic completion transport are source-unit evidence, not provider acceptance. No claim of real OAuth interoperability, Windows launch acceptance or OS credential-vault storage. Tokens/client JSON are deliberately session memory only.

Security-sensitive path: explicit browser sign-in only; official fixed HTTPS endpoints, no redirects/TLS bypass; loopback bounded ephemeral callback; PKCE/state; minimal scopes; typed payload preview/one-use ID/SHA-256 binding; durable audit intent before HTTP; fail closed on stale save; no automatic retries; UNKNOWN on interrupted POST; explicit Google revocation separate from immediate local clear. Root independent review remains required before pushing this local source commit.
