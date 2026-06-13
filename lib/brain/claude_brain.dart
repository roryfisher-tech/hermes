import 'dart:convert';
import 'package:http/http.dart' as http;

import 'brain.dart';
import '../models/chat_turn.dart';
import '../models/memory_item.dart';
import '../connectors/models.dart';

/// Claude-backed brain. Talks to the Anthropic Messages API directly.
///
/// The system prompt does several jobs: adopt the persona, use on-device
/// memory, stay accurate (flag uncertainty), learn durable facts, and — new —
/// decide when to use a tool by returning an "action".
class ClaudeBrain implements Brain {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-8';
  static const _apiVersion = '2023-06-01';
  static const _maxTokens = 2048;

  final String apiKey;
  ClaudeBrain(this.apiKey);

  @override
  String get name => 'Claude Opus 4.8';

  static const _baseRules = '''
NON-NEGOTIABLE RULES ON ACCURACY (these ALWAYS take priority over personality,
tone, or staying in character):
- Verify before you assert. Do not present a guess as a fact.
- If you are not confident something is true, or it may be out of date, say so
  plainly and tell the user what should be double-checked.
- Separate what you know confidently, what comes from MEMORY, and what is
  uncertain. Use only data returned by TOOL RESULTs; never invent emails/events.

LEARNING:
- Decide which NEW, durable facts about the user are worth remembering
  (preferences, context, identity, recurring needs). Skip trivia and anything
  sensitive the user did not clearly consent to store.

OUTPUT FORMAT — respond with STRICT JSON only. No markdown, no code fences,
nothing outside the JSON object. Schema:
{
  "reply": "your message to the user",
  "uncertain": true | false,
  "uncertainty_note": "if uncertain, what to double-check; else empty string",
  "remember": [ {"key": "snake_case", "value": "the fact", "confidence": "high|medium|low"} ],
  "action": null | {"name": "tool_name", "args": { }, "summary": "one line for the user"}
}
If no tool is needed, set "action": null. If nothing new to remember, "remember": [].
''';

  List<Map<String, dynamic>> _composeSystemBlocks(
      String persona, String memory, String tools) {
    final identity = persona.trim().isEmpty
        ? 'You are Ada, a personal assistant dedicated to ONE specific user.'
        : persona.trim();

    final blocks = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': '$identity\n\n$_baseRules',
        'cache_control': {'type': 'ephemeral'},
      },
    ];

    if (tools.trim().isNotEmpty) {
      blocks.add({
        'type': 'text',
        'text': tools.trim(),
        'cache_control': {'type': 'ephemeral'},
      });
    }

    if (memory.trim().isNotEmpty) {
      blocks.add({
        'type': 'text',
        'text':
            'MEMORY (facts learned about the user, stored on-device only):\n${memory.trim()}',
      });
    }

    return blocks;
  }

  @override
  Future<BrainResponse> respond({
    required List<ChatTurn> history,
    String memoryContext = '',
    String personaInstruction = '',
    String toolCatalog = '',
  }) async {
    final messages = history.isEmpty
        ? [
            {'role': 'user', 'content': 'Hello'}
          ]
        : history.map((t) => t.toApiMessage()).toList();

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': _composeSystemBlocks(personaInstruction, memoryContext, toolCatalog),
        'messages': messages,
      }),
    );

    if (res.statusCode != 200) {
      throw BrainException('Claude API ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final blocks = (data['content'] as List?) ?? const [];
    final raw = blocks
        .where((b) => b is Map && b['type'] == 'text')
        .map((b) => (b as Map)['text']?.toString() ?? '')
        .join('\n')
        .trim();

    return _parse(raw);
  }

  /// Parse the structured JSON, falling back to plain prose if malformed.
  BrainResponse _parse(String raw) {
    var text = raw;
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '').trim();
    }
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;

      final remember = ((j['remember'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => MemoryItem(
                key: (m['key'] ?? '').toString(),
                value: (m['value'] ?? '').toString(),
                confidence: (m['confidence'] ?? 'medium').toString(),
              ))
          .where((m) => m.key.isNotEmpty && m.value.isNotEmpty)
          .toList();

      ProposedAction? action;
      final a = j['action'];
      if (a is Map && (a['name'] ?? '').toString().isNotEmpty) {
        action = ProposedAction(
          name: a['name'].toString(),
          args: (a['args'] is Map)
              ? (a['args'] as Map).map((k, v) => MapEntry(k.toString(), v))
              : const {},
          summary: (a['summary'] ?? '').toString(),
        );
      }

      return BrainResponse(
        reply: (j['reply'] ?? '').toString(),
        uncertain: j['uncertain'] == true,
        uncertaintyNote: (j['uncertainty_note'] ?? '').toString(),
        remember: remember,
        action: action,
      );
    } catch (_) {
      return BrainResponse(reply: raw);
    }
  }
}

class BrainException implements Exception {
  final String message;
  BrainException(this.message);
  @override
  String toString() => message;
}
