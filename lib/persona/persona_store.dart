import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/persona.dart';

/// Persists the agent's persona on-device, in its own small JSON file.
/// Kept separate from memory: this is who the agent *is*, not what it knows
/// about you.
class PersonaStore {
  static const _fileName = 'hermes_persona.json';
  Persona _persona = const Persona();

  Persona get persona => _persona;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> load() async {
    final f = await _file();
    if (!await f.exists()) return;
    try {
      _persona =
          Persona.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      _persona = const Persona();
    }
  }

  Future<void> save(Persona p) async {
    _persona = p;
    final f = await _file();
    await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert(p.toJson()));
  }
}
