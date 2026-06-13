import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'connectors.dart';
import 'models.dart';

/// Outlook email connector (Microsoft Graph v1.0). Needs an OAuth access token
/// with Mail.Read and Mail.Send scopes. See CONNECT_SETUP.md.
class OutlookEmailConnector implements EmailConnector {
  static const _base = 'https://graph.microsoft.com/v1.0';
  final TokenSource auth;
  OutlookEmailConnector(this.auth);

  @override
  String get name => 'Outlook (Microsoft Graph)';
  @override
  bool get isConnected => true;
  @override
  Future<void> connect() async {}

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer ${await auth.token()}',
        'Content-Type': 'application/json',
      };

  String _addr(Map? m) =>
      (((m?['from'] ?? const {})['emailAddress'] ?? const {})['address'] ?? '')
          .toString();

  @override
  Future<List<Email>> list({int max = 10}) async {
    final uri = Uri.parse('$_base/me/messages'
        '?\$top=$max&\$orderby=receivedDateTime%20desc'
        '&\$select=id,subject,from,bodyPreview,receivedDateTime');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('Graph list ${res.statusCode}: ${res.body}');
    }
    final value = (jsonDecode(res.body)['value'] as List?) ?? const [];
    return value.whereType<Map>().map((m) {
      return Email(
        id: (m['id'] ?? '').toString(),
        from: _addr(m),
        subject: (m['subject'] ?? '(no subject)').toString(),
        snippet: (m['bodyPreview'] ?? '').toString(),
        date: DateTime.tryParse((m['receivedDateTime'] ?? '').toString()) ??
            DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<Email?> get(String id) async {
    final uri = Uri.parse(
        '$_base/me/messages/$id?\$select=id,subject,from,body,receivedDateTime');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map;
    return Email(
      id: (m['id'] ?? '').toString(),
      from: _addr(m),
      subject: (m['subject'] ?? '').toString(),
      body: (((m['body'] ?? const {})['content']) ?? '').toString(),
      date: DateTime.tryParse((m['receivedDateTime'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  @override
  Future<void> send(EmailDraft d) async {
    final body = jsonEncode({
      'message': {
        'subject': d.subject,
        'body': {'contentType': 'Text', 'content': d.body},
        'toRecipients': [
          {
            'emailAddress': {'address': d.to}
          }
        ],
      },
      'saveToSentItems': true,
    });
    final res = await http.post(Uri.parse('$_base/me/sendMail'),
        headers: await _headers(), body: body);
    if (res.statusCode != 202) {
      throw Exception('Graph send ${res.statusCode}: ${res.body}');
    }
  }

  @override
  Future<void> reply(String id, String bodyText) async {
    final res = await http.post(
      Uri.parse('$_base/me/messages/$id/reply'),
      headers: await _headers(),
      body: jsonEncode({'comment': bodyText}),
    );
    if (res.statusCode != 202) {
      throw Exception('Graph reply ${res.statusCode}: ${res.body}');
    }
  }
}
