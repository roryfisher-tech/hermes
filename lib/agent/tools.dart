import 'dart:convert';

import '../connectors/connectors.dart';
import '../connectors/models.dart';

/// The catalog injected into the system prompt so Ada knows what she can do.
const String toolCatalog = '''
TOOLS — to use one, return an "action" object in your JSON (one tool per turn).
Read tools run immediately and their result comes back to you on the next turn.
Approval tools are only PROPOSED: the user must approve before anything happens.

Read:
- list_emails {"max": int?}            -> recent inbox (id, from, subject, snippet, date)
- read_email  {"id": string}           -> full email body
- list_events {"days": int?}           -> upcoming calendar events

Needs user approval (you are only proposing — do NOT claim it is done):
- send_email   {"to","subject","body"}
- reply_email  {"id","body"}           -> reply to an email by id
- create_event {"title","start","end","notes"?}  (ISO-8601 times)

Action rules:
- "action": {"name": "...", "args": {...}, "summary": "one short line for the user"} or null.
- Use ONLY data returned by tools. Never invent emails or events.
- For approval tools, tell the user you've prepared it and are awaiting their OK.
''';

/// Write/sensitive tools require explicit user approval before running.
bool requiresApproval(String toolName) => const {
      'send_email',
      'reply_email',
      'create_event',
    }.contains(toolName);

bool isKnownTool(String toolName) => const {
      'list_emails',
      'read_email',
      'list_events',
      'send_email',
      'reply_email',
      'create_event',
    }.contains(toolName);

/// Execute a tool and return a compact string result to feed back to the brain.
/// (Called for read tools automatically, and for write tools only after the
/// user has approved.)
Future<String> runTool(ProposedAction a, Connectors c) async {
  try {
    switch (a.name) {
      case 'list_emails':
        final max = (a.args['max'] is int) ? a.args['max'] as int : 10;
        final list = await c.email.list(max: max);
        return jsonEncode(list.map((e) => e.toBrief()).toList());

      case 'read_email':
        final e = await c.email.get(a.argStr('id'));
        return e == null ? 'Email not found.' : jsonEncode({...e.toBrief(), 'body': e.body});

      case 'list_events':
        final days = (a.args['days'] is int) ? a.args['days'] as int : 7;
        final list = await c.calendar.upcoming(days: days);
        return jsonEncode(list.map((e) => e.toBrief()).toList());

      case 'send_email':
        await c.email.send(EmailDraft(
          to: a.argStr('to'),
          subject: a.argStr('subject'),
          body: a.argStr('body'),
        ));
        return 'Email sent to ${a.argStr('to')}.';

      case 'reply_email':
        await c.email.reply(a.argStr('id'), a.argStr('body'));
        return 'Reply sent.';

      case 'create_event':
        await c.calendar.create(CalendarEvent(
          title: a.argStr('title'),
          start: DateTime.tryParse(a.argStr('start')) ?? DateTime.now(),
          end: DateTime.tryParse(a.argStr('end')) ??
              DateTime.now().add(const Duration(hours: 1)),
          notes: a.argStr('notes'),
        ));
        return 'Event "${a.argStr('title')}" created.';

      default:
        return 'Unknown tool: ${a.name}';
    }
  } catch (e) {
    return 'Tool ${a.name} failed: $e';
  }
}
