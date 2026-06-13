# Ada — your step-by-step task list

Work top to bottom. Parts A–B get it running; C adds Android; D–E connect
email/calendar; F is what to build next. Tick boxes as you go.

---

## Part A — Get it running on your PC (do this first)

- [ ] **1. Install Flutter.** Follow docs.flutter.dev/get-started/install for your
      OS. Then run `flutter doctor` and fix anything it flags (red ✗).
- [ ] **2. (Optional) Install VS Code** + the "Flutter" extension. Makes running
      and debugging much easier.
- [ ] **3. Unzip the project** (`hermes.zip`) somewhere you'll find it. Open a
      terminal in the `hermes/` folder (the one with `pubspec.yaml`).
- [ ] **4. Generate the platform folders** (the zip only has the code):
      ```
      flutter create --platforms=android,windows,linux,macos .
      ```
- [ ] **5. Get dependencies:** `flutter pub get`
      (if it complains about versions, run `flutter pub upgrade`).
- [ ] **6. Check it compiles:** `flutter analyze`. Fix any errors it reports.
      (Harmless warnings like `withOpacity` deprecation are fine to ignore.)
- [ ] **7. Get an Anthropic API key** at console.anthropic.com → API Keys →
      Create. Copy it (starts with `sk-ant-`). Keep it private.
- [ ] **8. Run on desktop** (easiest first target):
      ```
      flutter run -d windows      # or: -d macos  /  -d linux
      ```
      If no desktop device shows in `flutter devices`, enable it once, e.g.
      `flutter config --enable-windows-desktop`, then retry.
- [ ] **9. Enter your API key** when Ada asks on first launch, then send a
      message. You should get a reply.

---

## Part B — Try the core features (5 minutes)

- [ ] **10. Memory:** tell Ada a fact ("I prefer metric units"), then open the
      ⋯ → no — the brain icon (Memory) and confirm it was saved.
- [ ] **11. Persona:** tap the face icon → change her name/voice/age → Save.
- [ ] **12. Voice:** make sure she speaks (toggle the speaker icon to mute/unmute).
- [ ] **13. Pop-up:** ⋯ menu → Test pop-up → confirm a notification appears.
- [ ] **14. Session:** fully close the app and reopen it — your conversation
      should still be there.
- [ ] **15. Tools (mock):** ask "what's in my inbox?" then "reply to the VDAB
      email saying I'll be there." Ada drafts it and shows an **approval card** —
      tap Approve and confirm she reports it sent (to the mock).

---

## Part C — Run on your Android phone

- [ ] **16. Open** `android/app/src/main/AndroidManifest.xml` and make sure these
      are present (add inside `<manifest>` if missing):
      ```
      <uses-permission android:name="android.permission.INTERNET"/>
      <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
      ```
- [ ] **17. Enable Developer mode + USB debugging** on your phone, plug it in
      (or start an Android emulator).
- [ ] **18. Run:** `flutter run` (pick your phone if asked). Allow the
      notification permission prompt on first launch.

---

## Part D — Connect email + calendar LIVE (quick test with a token)

This proves the real connectors work before building full login.

- [ ] **19. Outlook token:** open Microsoft Graph Explorer
      (developer.microsoft.com/graph/graph-explorer), sign in, consent to
      **Mail.Read** + **Mail.Send**, copy the access token from the
      "Access token" tab.
- [ ] **20.** In Ada: ⋯ → Connections → Outlook → **Connect** → paste the token.
- [ ] **21. Google Calendar token:** open the OAuth 2.0 Playground
      (developers.google.com/oauthplayground), select scope
      `https://www.googleapis.com/auth/calendar.events`, authorize, exchange for
      tokens, copy the access token.
- [ ] **22.** In Ada: Connections → Google Calendar → **Connect** → paste it.
- [ ] **23. Test live:** "what's on my calendar this week?" and "reply to the
      latest email confirming I'll attend." Approve the draft when prompted.
      (Tokens last ~1 hour — re-paste when they expire.)

---

## Part E — Real OAuth login (for permanent, everyday use)

See `CONNECT_SETUP.md` for full detail. High level:

- [ ] **24. Microsoft:** Azure Portal → App registrations → register an app;
      add Graph delegated scopes **Mail.Read, Mail.Send, offline_access**; note
      the client ID and add a redirect URI per platform.
- [ ] **25. Google:** Google Cloud Console → new project → enable **Calendar
      API** → configure consent screen → create OAuth client IDs.
- [ ] **26.** Add a real `TokenSource` that runs PKCE login and refreshes tokens
      (packages: `flutter_appauth` on Android; `oauth2`/`googleapis_auth`
      loopback on desktop), storing the refresh token in secure storage.
- [ ] **27.** In `lib/ui/chat_screen.dart` `_buildAgent`, construct the
      connectors with that real `TokenSource` instead of `StaticTokenSource`.
      *(This is the piece to build with me next session if you want help.)*

---

## Part F — What to build next (tell me which)

- [ ] **28. Full OAuth flow** (Part E, steps 26–27) — so you stop pasting tokens.
- [ ] **29. Phase 3 — Proactive engine:** Ada watches for new mail / upcoming
      events and pops up on her own (scheduler + triggers + an importance filter
      so she doesn't spam you).
- [ ] **30. Phase 4 — Desktop tray + Android background service** for reliable
      background running.

---

## Quick gotchas
- **Linux desktop:** `flutter_secure_storage` needs `libsecret-1-dev`
  (build) / `libsecret-1-0` (runtime); TTS needs a speech engine installed.
- **API key safety:** it lives encrypted on your device. Fine for personal use;
  if you ever share the app, put a small backend between it and Anthropic.
- **If a reply looks wrong or made-up:** Ada flags uncertainty in an amber note —
  trust that over a confident-sounding guess.
