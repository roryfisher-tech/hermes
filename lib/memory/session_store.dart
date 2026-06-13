import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/chat_turn.dart';

/// Persists the conversation on-device so a session can be resumed next time
/// the app opens. Like everything else, it lives only on this device.
class SessionStore {
  static const _fileName = 'hermes_session.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<ChatTurn>> load() async {
    final f = await _file();
    if (!await f.exists()) return [];
    try {
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .whereType<Map>()
          .map((m) => ChatTurn.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ChatTurn> turns) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(turns.map((t) => t.toJson()).toList()));
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
