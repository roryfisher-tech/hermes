# Connecting Outlook (email) + Google Calendar

Ada keeps email and calendar as **separate, swappable connectors**, so this
setup wires Outlook for mail and Google for calendar. Each needs an OAuth
access token. There are two stages: a quick test, then real login.

The permission rule is unchanged: reading is free; **sending mail or creating
events always shows an approval card first**.

---

## Stage 1 — Test live in 5 minutes (paste a token)

This proves the real connectors work before you build a full login flow.

**Outlook (Microsoft Graph)**
1. Open Microsoft Graph Explorer (developer.microsoft.com/graph/graph-explorer).
2. Sign in with your Outlook/Microsoft account and consent to **Mail.Read** and
   **Mail.Send**.
3. Copy the **access token** from the "Access token" tab.
4. In Ada: ⋯ menu → Connections → next to Outlook tap **Connect** → paste it.

**Google Calendar**
1. Open the Google OAuth 2.0 Playground (developers.google.com/oauthplayground).
2. In Step 1 select the **Calendar API v3** scope
   `https://www.googleapis.com/auth/calendar.events`, authorize, then in Step 2
   click "Exchange authorization code for tokens".
3. Copy the **access token**.
4. In Ada: Connections → next to Google Calendar tap **Connect** → paste it.

These tokens are short-lived (≈1 hour). Re-paste when they expire. Once pasted,
try: "what's on my calendar this week?" or "reply to the latest email saying I'll
confirm tomorrow" — Ada drafts it and waits for your Approve.

---

## Stage 2 — Real login (for everyday use)

You register an app with each provider, then add an OAuth flow that fills the
`TokenSource` (replace `StaticTokenSource` with a real one that refreshes).

### Microsoft (Outlook)
1. Azure Portal → App registrations → New registration.
2. Supported accounts: personal + work/school as you need.
3. Add a redirect URI per platform (see below). Note the **Application (client) ID**.
4. API permissions → Microsoft Graph → delegated → **Mail.Read**, **Mail.Send**,
   `offline_access` (for refresh tokens).
5. Auth endpoints:
   `https://login.microsoftonline.com/common/oauth2/v2.0/authorize` and `/token`.

### Google (Calendar)
1. Google Cloud Console → new project → enable **Google Calendar API**.
2. Configure the OAuth consent screen; add scope
   `https://www.googleapis.com/auth/calendar.events`.
3. Create OAuth client IDs (one per platform). Note client ID (+ secret for
   desktop/loopback).

### Flutter OAuth (cross-platform)
PKCE is the right flow for a client app. Recommended packages:
- **Android:** `flutter_appauth` — handles PKCE + redirect via a custom scheme
  (e.g. `com.yourapp://oauthredirect`).
- **Desktop (Windows/Linux/macOS):** the `oauth2` package with a **loopback**
  redirect (`http://localhost:<port>`), or `googleapis_auth`'s
  `clientViaUserConsent` for Google specifically.

Wire it as a `TokenSource` that:
1. runs the PKCE flow once, stores the **refresh token** in
   `flutter_secure_storage`, and
2. on `token()` returns a cached access token, refreshing it when expired.

Then in `chat_screen` `_buildAgent`, build the connectors with that real
`TokenSource` instead of `StaticTokenSource`.

---

## Reference docs (verify shapes against these)
- Microsoft Graph mail: `learn.microsoft.com/graph/api/resources/mail-api-overview`
  (`/me/messages`, `/me/sendMail`, `/me/messages/{id}/reply`).
- Google Calendar API v3: `developers.google.com/calendar/api/v3/reference`
  (`events.list`, `events.insert`).
