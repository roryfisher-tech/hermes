import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../agent/agent.dart';
import '../brain/brain.dart';
import '../brain/claude_brain.dart';
import '../connectors/connectors.dart';
import '../connectors/auth.dart';
import '../connectors/google_calendar.dart';
import '../connectors/outlook_email.dart';
import '../memory/memory_store.dart';
import '../memory/session_store.dart';
import '../models/chat_turn.dart';
import '../models/persona.dart';
import '../persona/persona_store.dart';
import '../services/notifier.dart';
import '../services/voice.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _keyName = 'anthropic_api_key';
  final _storage = const FlutterSecureStorage();
  final _memory = MemoryStore();
  final _session = SessionStore();
  final _personaStore = PersonaStore();
  final _notifier = Notifier();
  final _voice = VoiceService();
  EmailConnector _email = MockEmailConnector();
  CalendarConnector _calendar = MockCalendarConnector();
  static const _outlookTokenKey = 'outlook_token';
  static const _gcalTokenKey = 'gcal_token';
  final _input = TextEditingController();
  final _scroll = ScrollController();

  Agent? _agent;
  bool _busy = false;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _memory.load();
    await _personaStore.load();
    await _notifier.init();
    await _voice.init();
    final outlookTok = await _storage.read(key: _outlookTokenKey);
    if (outlookTok != null && outlookTok.isNotEmpty) {
      _email = OutlookEmailConnector(StaticTokenSource(outlookTok));
    }
    final gcalTok = await _storage.read(key: _gcalTokenKey);
    if (gcalTok != null && gcalTok.isNotEmpty) {
      _calendar = GoogleCalendarConnector(StaticTokenSource(gcalTok));
    }
    await _email.connect();
    await _calendar.connect();
    final key = await _storage.read(key: _keyName);
    if (key != null && key.isNotEmpty) {
      _buildAgent(key);
      await _agent!.restore();
    }
    setState(() => _booting = false);
    if (key == null || key.isEmpty) _promptForKey();
  }

  void _buildAgent(String key) {
    final Brain brain = ClaudeBrain(key);
    _agent = Agent(
      brain: brain,
      memory: _memory,
      session: _session,
      notifier: _notifier,
      connectors: Connectors(email: _email, calendar: _calendar),
      persona: _personaStore.persona,
    );
  }

  Future<void> _promptForKey() async {
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Anthropic API key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'sk-ant-...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (key != null && key.isNotEmpty) {
      await _storage.write(key: _keyName, value: key);
      _buildAgent(key);
      await _agent!.restore();
      setState(() {});
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _agent == null || _busy) return;
    _input.clear();
    setState(() => _busy = true);
    try {
      final result = await _agent!.send(text);
      if (_agent!.persona.voiceEnabled) await _voice.speak(result.turn.text);
    } catch (e) {
      _agent!.history.add(ChatTurn(
        role: Role.assistant,
        text: 'Something went wrong: $e',
        uncertain: true,
        uncertaintyNote: 'Check your API key and network connection.',
      ));
    } finally {
      setState(() => _busy = false);
      _jumpToBottom();
    }
  }

  Future<void> _resolveAction(ChatTurn turn, bool approved) async {
    final action = turn.pendingAction;
    if (action == null || _agent == null || _busy) return;
    turn.pendingAction = null; // consume so the card disappears
    setState(() => _busy = true);
    try {
      final result =
          approved ? await _agent!.approve(action) : await _agent!.decline(action);
      if (_agent!.persona.voiceEnabled) await _voice.speak(result.turn.text);
    } catch (e) {
      _agent!.history.add(ChatTurn(
        role: Role.assistant,
        text: 'That action failed: $e',
        uncertain: true,
      ));
    } finally {
      setState(() => _busy = false);
      _jumpToBottom();
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _showMemory() async {
    final facts = _agent?.knownFacts ?? _memory.all;
    final path = await _memory.path();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What Hermes has learned'),
        content: SizedBox(
          width: double.maxFinite,
          child: facts.isEmpty
              ? const Text('Nothing yet. It learns as you talk.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in facts)
                      ListTile(
                        dense: true,
                        title: Text('${f.key}: ${f.value}'),
                        subtitle: Text('confidence: ${f.confidence}'),
                      ),
                    const Divider(),
                    Text('Stored only on this device at:\n$path',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _memory.clear();
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Wipe memory'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPersona() async {
    final current = _agent?.persona ?? _personaStore.persona;
    final nameCtl = TextEditingController(text: current.name);
    final pronounsCtl = TextEditingController(text: current.pronouns);
    final ageCtl = TextEditingController(text: current.age.toString());
    final personalityCtl = TextEditingController(text: current.personality);
    var gender = current.gender;
    var voiceEnabled = current.voiceEnabled;
    const genders = ['Female', 'Male', 'Non-binary', 'Unspecified'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Persona'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: genders.contains(gender) ? gender : 'Unspecified',
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: [
                    for (final g in genders)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (g) => setLocal(() {
                    gender = g ?? 'Unspecified';
                    pronounsCtl.text = Persona.pronounsFor(gender);
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pronounsCtl,
                  decoration: const InputDecoration(labelText: 'Pronouns'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age (approx.)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Speak replies aloud'),
                  value: voiceEnabled,
                  onChanged: (v) => setLocal(() => voiceEnabled = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: personalityCtl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Personality',
                    hintText: 'How should they speak and behave?',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final p in Persona.presets)
                      ActionChip(
                        label: Text(p.key),
                        onPressed: () =>
                            setLocal(() => personalityCtl.text = p.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final persona = Persona(
        name: nameCtl.text.trim().isEmpty ? 'Ada' : nameCtl.text.trim(),
        gender: gender,
        pronouns: pronounsCtl.text.trim().isEmpty
            ? Persona.pronounsFor(gender)
            : pronounsCtl.text.trim(),
        age: int.tryParse(ageCtl.text.trim()) ?? 35,
        personality: personalityCtl.text.trim().isEmpty
            ? const Persona().personality
            : personalityCtl.text.trim(),
        voiceEnabled: voiceEnabled,
      );
      await _personaStore.save(persona);
      _agent?.setPersona(persona);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final turns =
        (_agent?.history ?? const <ChatTurn>[]).where((t) => t.role != Role.tool).toList();
    final name = _agent?.persona.name ?? _personaStore.persona.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Persona',
            icon: const Icon(Icons.face_outlined),
            onPressed: _editPersona,
          ),
          IconButton(
            tooltip: (_agent?.persona.voiceEnabled ?? true)
                ? 'Mute voice'
                : 'Unmute voice',
            icon: Icon((_agent?.persona.voiceEnabled ?? true)
                ? Icons.volume_up_outlined
                : Icons.volume_off_outlined),
            onPressed: () async {
              final p = _agent?.persona ?? _personaStore.persona;
              final updated = p.copyWith(voiceEnabled: !p.voiceEnabled);
              await _personaStore.save(updated);
              _agent?.setPersona(updated);
              if (!updated.voiceEnabled) await _voice.stop();
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Memory',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: _showMemory,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'connections':
                  _showConnections();
                  break;
                case 'popup':
                  _notifier.popup(name, 'This is a test pop-up.');
                  break;
                case 'key':
                  _promptForKey();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'connections', child: Text('Connections')),
              PopupMenuItem(value: 'popup', child: Text('Test pop-up')),
              PopupMenuItem(value: 'key', child: Text('Change API key')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: turns.length,
              itemBuilder: (_, i) => _bubble(turns[i]),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _agent == null
                            ? 'Add your API key to start'
                            : 'Message $name…',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _agent == null ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatTurn t) {
    final isUser = t.role == Role.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.text),
            if (t.uncertain) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.uncertaintyNote.isEmpty
                            ? 'Not fully certain — please double-check.'
                            : t.uncertaintyNote,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (t.pendingAction != null) ...[
              const SizedBox(height: 8),
              _approvalCard(t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _approvalCard(ChatTurn t) {
    final a = t.pendingAction!;
    final details = <String>[];
    switch (a.name) {
      case 'send_email':
        details.addAll([
          'To: ${a.argStr('to')}',
          'Subject: ${a.argStr('subject')}',
          '',
          a.argStr('body'),
        ]);
        break;
      case 'reply_email':
        details.addAll(['Reply to: ${a.argStr('id')}', '', a.argStr('body')]);
        break;
      case 'create_event':
        details.addAll([
          'Event: ${a.argStr('title')}',
          'Start: ${a.argStr('start')}',
          'End: ${a.argStr('end')}',
          if (a.argStr('notes').isNotEmpty) 'Notes: ${a.argStr('notes')}',
        ]);
        break;
      default:
        details.add(a.summary);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Needs your approval',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(details.join('\n'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _resolveAction(t, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _busy ? null : () => _resolveAction(t, true),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _pasteToken(String title) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paste an OAuth access token (see CONNECT_SETUP.md)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: const Text('Connect')),
        ],
      ),
    );
  }

  Future<void> _connectOutlook(VoidCallback refresh) async {
    final tok = await _pasteToken('Connect Outlook');
    if (tok == null || tok.isEmpty) return;
    await _storage.write(key: _outlookTokenKey, value: tok);
    _email = OutlookEmailConnector(StaticTokenSource(tok));
    _agent?.connectors.email = _email;
    refresh();
    setState(() {});
  }

  Future<void> _connectGcal(VoidCallback refresh) async {
    final tok = await _pasteToken('Connect Google Calendar');
    if (tok == null || tok.isEmpty) return;
    await _storage.write(key: _gcalTokenKey, value: tok);
    _calendar = GoogleCalendarConnector(StaticTokenSource(tok));
    _agent?.connectors.calendar = _calendar;
    refresh();
    setState(() {});
  }

  Future<void> _disconnect({required bool emailSide, required VoidCallback refresh}) async {
    if (emailSide) {
      await _storage.delete(key: _outlookTokenKey);
      _email = MockEmailConnector();
      await _email.connect();
      _agent?.connectors.email = _email;
    } else {
      await _storage.delete(key: _gcalTokenKey);
      _calendar = MockCalendarConnector();
      await _calendar.connect();
      _agent?.connectors.calendar = _calendar;
    }
    refresh();
    setState(() {});
  }

  Future<void> _showConnections() async {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final emailReal = _email is OutlookEmailConnector;
          final calReal = _calendar is GoogleCalendarConnector;
          return AlertDialog(
            title: const Text('Connections'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(emailReal
                      ? Icons.check_circle
                      : Icons.science_outlined),
                  title: Text(_email.name),
                  subtitle: Text(emailReal ? 'Connected (live)' : 'Mock data'),
                  trailing: TextButton(
                    onPressed: () => emailReal
                        ? _disconnect(emailSide: true, refresh: () => setLocal(() {}))
                        : _connectOutlook(() => setLocal(() {})),
                    child: Text(emailReal ? 'Disconnect' : 'Connect'),
                  ),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(
                      calReal ? Icons.check_circle : Icons.science_outlined),
                  title: Text(_calendar.name),
                  subtitle: Text(calReal ? 'Connected (live)' : 'Mock data'),
                  trailing: TextButton(
                    onPressed: () => calReal
                        ? _disconnect(emailSide: false, refresh: () => setLocal(() {}))
                        : _connectGcal(() => setLocal(() {})),
                    child: Text(calReal ? 'Disconnect' : 'Connect'),
                  ),
                ),
                const Divider(),
                const Text(
                  'Paste a short-lived access token to test live, or wire full '
                  'OAuth (see CONNECT_SETUP.md). Sending and calendar changes '
                  'always ask for your approval first.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }
}
