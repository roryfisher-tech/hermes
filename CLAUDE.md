# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                                    # install dependencies
flutter create --platforms=android,windows,linux,macos .  # generate platform folders (first time only)
flutter analyze                                    # type-check + lint
flutter run -d windows                             # run on desktop
flutter run                                        # run on connected Android device/emulator
```

If `flutter pub get` fails to resolve, run `flutter pub upgrade` instead.

## Architecture

Hermes is a personal AI assistant (called **Ada**) built in Flutter for Windows and Android. The app's key design principle is that every major component is behind a clean, swappable interface — changing the AI model, memory backend, or data connectors never touches unrelated modules.

### Component map

```
ChatScreen (ui/chat_screen.dart)
  └─ Agent (agent/agent.dart)          — orchestrates a turn: brain → tools → memory
       ├─ Brain (brain/brain.dart)      — abstract interface; impl: ClaudeBrain
       ├─ MemoryStore (memory/)         — on-device JSON facts, injected as context each turn
       ├─ SessionStore (memory/)        — on-device JSON conversation history
       ├─ Connectors (connectors/)      — email + calendar, abstract + mock + real impls
       ├─ Persona (models/persona.dart) — name, pronouns, age, personality, injected into system prompt
       └─ Notifier (services/notifier.dart) — native pop-ups
```

### The turn loop (agent/agent.dart `_drive`)

1. `MemoryStore.buildContext()` renders known facts into a context block.
2. `Brain.respond()` receives full history + memory context + persona instruction + tool catalog, returns a `BrainResponse`.
3. If `BrainResponse.action` is a **read tool** (`list_emails`, `read_email`, `list_events`): run it, append the result as a `Role.tool` turn, loop back to step 2 (max 5 iterations).
4. If `BrainResponse.action` is a **write tool** (`send_email`, `reply_email`, `create_event`): surface an approval card in the UI — nothing executes until the user taps Approve. After approval, call `Agent.approve(action)` which runs the tool and feeds the result back.
5. If no action (or unknown tool): final reply. Write new `remember` facts to `MemoryStore`.

### Brain response format

`ClaudeBrain` expects the model to return strict JSON (no markdown fences):
```json
{
  "reply": "...",
  "uncertain": true | false,
  "uncertainty_note": "...",
  "remember": [{"key": "snake_case", "value": "...", "confidence": "high|medium|low"}],
  "action": null | {"name": "tool_name", "args": {}, "summary": "one line for the user"}
}
```
The `_parse` fallback in `claude_brain.dart` gracefully handles malformed output by treating the raw text as the reply.

### Connectors

`EmailConnector` and `CalendarConnector` are abstract interfaces in `connectors/connectors.dart`. Mock implementations are the default; real connectors (`OutlookEmailConnector`, `GoogleCalendarConnector`) are activated by supplying a `TokenSource` via the Connections panel in the UI. The `TokenSource` abstraction (`connectors/auth.dart`) currently ships only `StaticTokenSource` (paste a short-lived token); a full PKCE + refresh-token implementation is the next planned step (see `CONNECT_SETUP.md`).

### On-device storage

All three stores use `path_provider` to find the documents directory and write plain JSON:
- `hermes_memory.json` — keyed facts the agent learns
- `hermes_session.json` — full conversation history
- Persona and OAuth tokens use `flutter_secure_storage`

### Swapping the brain

Implement `Brain` (in `brain/brain.dart`) and call `agent.setBrain(newBrain)`. The rest of the app is unaffected. The current implementation (`ClaudeBrain`) calls the Anthropic Messages API directly using `claude-opus-4-8`.

## Platform notes

- **flutter_tts** is disabled in `pubspec.yaml` — needs extra native setup on Windows. Re-add and enable the `VoiceService` in `services/voice.dart` to restore spoken replies.
- **Linux:** `flutter_secure_storage` needs `libsecret-1-dev` (build) and `libsecret-1-0` (runtime).
- **Android:** `POST_NOTIFICATIONS` permission must be in `AndroidManifest.xml`.
- The Anthropic API key is entered on first launch and stored encrypted via `flutter_secure_storage`.
