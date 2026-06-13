import 'models.dart';

/// Swappable email backend. The Google/Outlook/IMAP adapter implements this;
/// the rest of the app only knows this interface (mirrors the Brain pattern).
abstract class EmailConnector {
  String get name;
  bool get isConnected;
  Future<void> connect();
  Future<List<Email>> list({int max = 10});
  Future<Email?> get(String id);
  Future<void> send(EmailDraft draft);
  Future<void> reply(String id, String body);
}

/// Swappable calendar backend.
abstract class CalendarConnector {
  String get name;
  bool get isConnected;
  Future<void> connect();
  Future<List<CalendarEvent>> upcoming({int days = 7});
  Future<void> create(CalendarEvent event);
}

/// Holds whichever connectors are active. Wire real adapters here later.
class Connectors {
  EmailConnector email;
  CalendarConnector calendar;
  Connectors({required this.email, required this.calendar});
}

// ---------------------------------------------------------------------------
// Mock implementations — let the whole permission-gated flow run today with no
// OAuth setup. The real adapters replace these behind the same interface.
// ---------------------------------------------------------------------------

class MockEmailConnector implements EmailConnector {
  bool _connected = false;
  final List<Email> _inbox = [
    Email(
      id: 'm1',
      from: 'team@vdab.be',
      subject: 'Afspraak bevestiging',
      snippet: 'Beste, hierbij bevestigen we uw afspraak van volgende week...',
      body: 'Beste, hierbij bevestigen we uw afspraak van volgende week dinsdag om 10u.',
      date: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Email(
      id: 'm2',
      from: 'newsletter@flutter.dev',
      subject: 'Flutter weekly digest',
      snippet: 'This week in Flutter: new tooling, packages, and talks...',
      body: 'This week in Flutter: new tooling, packages, and talks.',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
  final List<EmailDraft> sent = [];

  @override
  String get name => 'Mock email';
  @override
  bool get isConnected => _connected;
  @override
  Future<void> connect() async => _connected = true;
  @override
  Future<List<Email>> list({int max = 10}) async => _inbox.take(max).toList();
  @override
  Future<Email?> get(String id) async =>
      _inbox.where((e) => e.id == id).cast<Email?>().firstWhere((_) => true, orElse: () => null);
  @override
  Future<void> send(EmailDraft draft) async => sent.add(draft);
  @override
  Future<void> reply(String id, String body) async {
    final original = await get(id);
    sent.add(EmailDraft(
      to: original?.from ?? '',
      subject: 'Re: ${original?.subject ?? ''}',
      body: body,
    ));
  }
}

class MockCalendarConnector implements CalendarConnector {
  bool _connected = false;
  final List<CalendarEvent> _events = [
    CalendarEvent(
      id: 'e1',
      title: 'Dentist',
      start: DateTime.now().add(const Duration(days: 2, hours: 9)),
      end: DateTime.now().add(const Duration(days: 2, hours: 10)),
    ),
  ];

  @override
  String get name => 'Mock calendar';
  @override
  bool get isConnected => _connected;
  @override
  Future<void> connect() async => _connected = true;
  @override
  Future<List<CalendarEvent>> upcoming({int days = 7}) async {
    final cutoff = DateTime.now().add(Duration(days: days));
    return _events.where((e) => e.start.isBefore(cutoff)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<void> create(CalendarEvent event) async => _events.add(event);
}
