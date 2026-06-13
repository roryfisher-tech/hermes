# Hermes

A personal **learning agent** for **PC and Android**, built with one Flutter codebase.

- **Brain:** Claude Opus 4.8 (`claude-opus-4-8`) — behind a swappable interface.
- **Memory:** a single JSON file that lives **only on your device** and grows as the agent learns you. It's plain and inspectable — you own it, you can read or wipe it.
- **Accuracy first:** the agent is instructed to verify before asserting and to **say so plainly when it's unsure**, surfaced as an amber note in the UI.
- **Pop-ups:** native notifications on Android and desktop.
- **Persona:** give the agent a name, gender/pronouns, **age**, and personality — persisted on-device and injected into the brain so it adopts the voice (without ever overriding the accuracy rules).
- **Spoken replies:** an optional female text-to-speech voice (British English by default), with a one-tap mute. Availability depends on the OS — Android/Windows/macOS work out of the box; Linux may need a TTS engine.
- **Session persistence:** the conversation, memory, and persona are all saved on-device and restored on launch, so you can pick up where you left off.
- **Tools (email & calendar):** Ada can read your inbox/calendar and *propose* emails, replies, and events. Anything that sends or changes data is gated behind an in-app **approval card** — nothing happens until you tap Approve. Connectors are swappable and independent: **Outlook** (Microsoft Graph) for mail and **Google Calendar** for events ship as real connectors, with a mock backend as the default until you connect. See CONNECT_SETUP.md.
- **Built to extend:** every part (brain, memory, persona, voice, connectors, notifications, UI) is its own module behind a clean boundary.

---

## How it fits together

```
            ┌──────────────┐
   you ───► │   Chat UI     │ ──► shows reply + uncertainty flag
            └──────┬───────┘
                   │
            ┌──────▼───────┐
            │    Agent      │  load memory → ask brain → learn → reply
            └──┬───────┬───┘
       ┌───────┘       └────────┐
┌──────▼──────┐         ┌───────▼───────┐
│   Brain      │         │  MemoryStore   │
│ (swappable)  │         │ on-device JSON │
│ ClaudeBrain  │         │  hermes_       │
│ → Opus 4.8   │         │  memory.json   │
└──────────────┘         └────────────────┘
        │
┌───────▼────────┐
│   Notifier      │  Android + desktop pop-ups
└─────────────────┘
```

### The learning loop (one turn)
1. `MemoryStore` renders known facts into a compact context block.
2. `Agent` sends *(your message + memory + recent history)* to the `Brain`.
3. The brain returns **structured JSON**: a reply, an `uncertain` flag + note, and any new `remember` facts.
4. `Agent` writes the new facts back to the on-device JSON file — so next time it's a little smarter.

---

## File layout

```
lib/
├─ main.dart                 app entry
├─ models/
│  ├─ chat_turn.dart         one message
│  ├─ memory_item.dart       a learned fact + the BrainResponse shape
│  └─ persona.dart           agent identity: name, gender, pronouns, personality
├─ brain/
│  ├─ brain.dart             abstract Brain interface (the swap point)
│  └─ claude_brain.dart      Claude Opus 4.8 implementation
├─ memory/
│  ├─ memory_store.dart      on-device JSON: load / save / learn / context
│  └─ session_store.dart     on-device JSON: saved conversation
├─ persona/
│  └─ persona_store.dart     on-device JSON: who the agent is
├─ agent/
│  ├─ agent.dart             orchestrator (brain + memory + persona + tools + notifier)
│  └─ tools.dart             tool catalog, approval rules, execution
├─ connectors/
│  ├─ models.dart            Email / CalendarEvent / EmailDraft / ProposedAction
│  ├─ connectors.dart        EmailConnector + CalendarConnector (abstract) + mocks
│  ├─ auth.dart              TokenSource (OAuth token abstraction)
│  ├─ outlook_email.dart     real Outlook email (Microsoft Graph)
│  └─ google_calendar.dart   real Google Calendar (Calendar API v3)
├─ services/
│  ├─ notifier.dart          pop-ups / notifications
│  └─ voice.dart             female text-to-speech
└─ ui/
   └─ chat_screen.dart       chat, key onboarding, memory viewer
```

---

## Run it

You need the Flutter SDK installed (https://docs.flutter.dev/get-started/install).

```bash
cd hermes
flutter pub get          # if anything fails to resolve: flutter pub upgrade

# create the platform folders for the targets you want:
flutter create --platforms=android,windows,linux,macos .

flutter run -d windows   # or: linux / macos
flutter run              # with an Android device/emulator attached
```

On first launch it asks for your **Anthropic API key** (get one at the Anthropic Console). It's stored encrypted on-device via `flutter_secure_storage`. The toolbar has buttons to test a pop-up, view/wipe memory, and change the key.

---

## Two honest caveats

- **Privacy line.** Storage is on-device only. But to use Claude as the brain, each turn sends the relevant slice of your memory to Anthropic's API to compute a reply. If you ever want *zero* data leaving the device, swap in a local model (see "Extend" below) — the rest of the app won't change.
- **API key in a client app.** Fine for a personal, single-user build (you enter your own key). For anything multi-user, put a small backend between the app and Anthropic so the key never ships to clients.

---

## Extend it (the code is open for this on purpose)

- **Swap the brain.** Implement `Brain` for a local/self-hosted model and call `agent.setBrain(...)`. Nothing else changes.
- **Add tools.** Give the brain function-calling (reminders, web search, files) and route calls through the `Agent`.
- **Make it proactive.** Add a scheduler/trigger module that calls `agent.ping(title, body)` for time- or event-based pop-ups.
- **Smarter memory.** Add categories, decay/expiry, or a vector index for semantic recall — `MemoryStore` is the only file you touch.

---

## Step plan / roadmap

- **Phase 1 — Foundation (this scaffold):** chat with Opus 4.8, on-device JSON memory + learning loop, uncertainty flagging, working pop-ups. ✅
- **Phase 2 — Tools & richer memory:** function-calling for reminders/notes/search; categorised memory + expiry.
- **Phase 3 — Proactivity engine:** scheduler + triggers + an importance filter so Hermes reaches out without being asked, without spamming.
- **Phase 4 — Cross-platform polish:** desktop tray + background service; Android foreground service for reliable background work.
- **Phase 5 — Sync & packaging:** optional encrypted PC↔phone sync; APK + desktop installers; hardening.
