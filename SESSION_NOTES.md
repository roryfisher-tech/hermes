# Ada — session notes (resume here)

## What Ada is
A personal **learning agent** for **PC + Android**, one Flutter codebase.

## Decisions locked
- **Brain:** Claude Opus 4.8 (`claude-opus-4-8`), swappable `Brain` interface.
- **Memory:** on-device JSON (`hermes_memory.json`), learning loop, JSON format.
- **Privacy:** local-first storage; context goes to Claude per request (cloud brain).
- **Accuracy:** verify-before-assert + uncertainty flag, outranks persona/tone.
- **Persona:** **Ada** — woman ~35, she/her; basic British-English female TTS
  (accent/sample picker intentionally left out); mute toggle.
- **Pop-ups:** native notifications + `agent.ping()` hook.
- **Session persistence:** conversation saved to `hermes_session.json`, restored on launch.

## NEW this session — Tools: email & calendar (Phase 2 started)
- **Permission model:** read tools (list/read inbox, list events) run freely;
  write tools (send_email, reply_email, create_event) are only PROPOSED and
  require an in-app **approval card** before anything happens. Ada is told she
  has NOT done a write action until the user approves.
- **Architecture:** swappable `EmailConnector` / `CalendarConnector` interfaces.
  A **mock connector** ships now so the full flow is testable without OAuth.
- **Brain/agent:** brain is now history-based and can return an `action`; the
  agent runs a small loop (run reads -> feed results back -> stop for approval
  on writes -> final reply). Internal tool-result turns are hidden in the UI.
- **UI:** approval card (Approve/Cancel) under proposed actions; a Connections
  entry in the overflow menu showing connector status.

## Real connectors built (this session)
- Provider mix chosen: **Outlook (email)** + **Google Calendar (events)** — the
  split connectors make mixing providers trivial.
- `OutlookEmailConnector` (Microsoft Graph) and `GoogleCalendarConnector`
  (Calendar v3) implemented as real REST clients that take a `TokenSource`.
- `auth.dart`: `TokenSource` abstraction + `StaticTokenSource` (paste a token).
- UI: Connections panel can paste a token to go live per provider, or disconnect
  back to mock. Tokens stored in secure storage; real connectors used on boot
  if present. See CONNECT_SETUP.md.

## NEXT — full OAuth login (replace StaticTokenSource)
1. Azure app registration (Mail.Read, Mail.Send, offline_access) + Google Cloud
   OAuth client (calendar.events). Per-platform redirect URIs.
2. Add a real `TokenSource` doing PKCE + refresh-token storage
   (flutter_appauth on Android; oauth2/googleapis_auth loopback on desktop).
3. Build connectors with it in chat_screen `_buildAgent`.
Until then: test live by pasting short-lived tokens (Graph Explorer / OAuth
Playground) via the Connections panel.

## Then (later phases)
- Phase 3 — Proactive engine: scheduler + triggers + importance filter (`agent.ping`).
- Phase 4 — Desktop tray + Android foreground service.
- Phase 5 — Optional encrypted PC<->phone sync; installers.

## To run
```bash
cd hermes
flutter pub get
flutter create --platforms=android,windows,linux,macos .
flutter analyze        # compile check (not run in the build environment)
flutter run
```
Try it with the mock: ask Ada "what's in my inbox?" then "reply to the VDAB
email saying I'll be there" — she'll draft it and wait for your Approve.
