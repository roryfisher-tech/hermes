import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'connectors.dart';
import 'models.dart';

/// Google Calendar connector (Calendar API v3). Needs an OAuth access token
/// with the calendar / calendar.events scope. See CONNECT_SETUP.md.
class GoogleCalendarConnector implements CalendarConnector {
  static const _base =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';
  final TokenSource auth;
  GoogleCalendarConnector(this.auth);

  @override
  String get name => 'Google Calendar';
  @override
  bool get isConnected => true; // a token source is configured
  @override
  Future<void> connect() async {}

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer ${await auth.token()}',
        'Content-Type': 'application/json',
      };

  @override
  Future<List<CalendarEvent>> upcoming({int days = 7}) async {
    final now = DateTime.now().toUtc();
    final uri = Uri.parse('$_base?singleEvents=true&orderBy=startTime'
        '&timeMin=${Uri.encodeComponent(now.toIso8601String())}&maxResults=20');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Calendar list ${res.statusCode}: ${res.body}');
    }
    final items = (jsonDecode(res.body)['items'] as List?) ?? const [];
    final cutoff = now.add(Duration(days: days));
    final events = <CalendarEvent>[];
    for (final it in items.whereType<Map>()) {
      final start = _time(it['start']);
      if (start == null || start.isAfter(cutoff)) continue;
      events.add(CalendarEvent(
        id: (it['id'] ?? '').toString(),
        title: (it['summary'] ?? '(no title)').toString(),
        start: start,
        end: _time(it['end']) ?? start,
        notes: (it['description'] ?? '').toString(),
      ));
    }
    return events;
  }

  @override
  Future<void> create(CalendarEvent e) async {
    final body = jsonEncode({
      'summary': e.title,
      if (e.notes.isNotEmpty) 'description': e.notes,
      'start': {'dateTime': e.start.toUtc().toIso8601String()},
      'end': {'dateTime': e.end.toUtc().toIso8601String()},
    });
    final res =
        await http.post(Uri.parse(_base), headers: await _headers(), body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Calendar create ${res.statusCode}: ${res.body}');
    }
  }

  DateTime? _time(dynamic node) {
    if (node is! Map) return null;
    final dt = node['dateTime'] ?? node['date'];
    return dt == null ? null : DateTime.tryParse(dt.toString());
  }
}
