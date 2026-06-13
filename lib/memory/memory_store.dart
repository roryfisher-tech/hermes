import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/memory_item.dart';

/// The on-device memory. This is the heart of Hermes: a single JSON file that
/// lives ONLY on the user's device and grows as the agent learns. It is plain
/// and inspectable on purpose — the user owns it and can read, edit, or wipe it.
///
/// File shape:
/// {
///   "version": 1,
///   "facts": { "<key>": { "value": "...", "confidence": "...", "updated_at": "..." } }
/// }
class MemoryStore {
  static const _fileName = 'hermes_memory.json';
  final Map<String, MemoryItem> _facts = {};

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Path on disk — handy to show the user where their data lives.
  Future<String> path() async => (await _file()).path;

  Future<void> load() async {
    final f = await _file();
    if (!await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final facts = (j['facts'] as Map?)?.cast<String, dynamic>() ?? {};
      _facts.clear();
      facts.forEach((k, v) {
        if (v is Map) {
          _facts[k] = MemoryItem.fromJson(k, v.cast<String, dynamic>());
        }
      });
    } catch (_) {
      // Corrupt file — start clean rather than crash. (Could back up here.)
    }
  }

  Future<void> save() async {
    final f = await _file();
    final facts = <String, dynamic>{};
    _facts.forEach((k, v) => facts[k] = v.toJson());
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'version': 1, 'facts': facts}),
    );
  }

  /// Merge in newly-learned facts (latest write wins per key) and persist.
  Future<void> learn(List<MemoryItem> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      _facts[item.key] = item;
    }
    await save();
  }

  /// Render the facts into a compact block the brain can read each turn.
  String buildContext() {
    if (_facts.isEmpty) return '';
    final b = StringBuffer('Known facts about the user:\n');
    for (final item in _facts.values) {
      b.writeln('- ${item.key}: ${item.value} (confidence: ${item.confidence})');
    }
    return b.toString().trim();
  }

  List<MemoryItem> get all => _facts.values.toList();

  Future<void> clear() async {
    _facts.clear();
    await save();
  }
}
