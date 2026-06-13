/// Plain data models for the email/calendar connectors. Provider-agnostic:
/// the Google (or any other) adapter maps its own types onto these.
library connectors.models;

class Email {
  final String id;
  final String from;
  final String to;
  final String subject;
  final String snippet; // short preview
  final String body; // full body (may be empty until fetched)
  final DateTime date;

  Email({
    required this.id,
    required this.from,
    this.to = '',
    required this.subject,
    this.snippet = '',
    this.body = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  /// Compact form fed back to the model as a tool result.
  Map<String, dynamic> toBrief() => {
        'id': id,
        'from': from,
        'subject': subject,
        'snippet': snippet.isNotEmpty ? snippet : body,
        'date': date.toIso8601String(),
      };
}

class EmailDraft {
  final String to;
  final String subject;
  final String body;
  const EmailDraft({required this.to, required this.subject, required this.body});
}

class CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String notes;

  CalendarEvent({
    this.id = '',
    required this.title,
    required this.start,
    required this.end,
    this.notes = '',
  });

  Map<String, dynamic> toBrief() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'notes': notes,
      };
}

/// A tool action the brain wants to take. For approval-gated tools (send/reply/
/// create), this is only a *proposal* until the user confirms.
class ProposedAction {
  final String name; // e.g. "send_email"
  final Map<String, dynamic> args;
  final String summary; // one-line human-readable description

  ProposedAction({
    required this.name,
    this.args = const {},
    this.summary = '',
  });

  String argStr(String key) => (args[key] ?? '').toString();
}
