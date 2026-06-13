import 'tools.dart' show toolCatalog, requiresApproval, isKnownTool, runTool;
import '../brain/brain.dart';
import '../connectors/connectors.dart';
import '../connectors/models.dart';
import '../memory/memory_store.dart';
import '../memory/session_store.dart';
import '../models/chat_turn.dart';
import '../models/memory_item.dart';
import '../models/persona.dart';
import '../services/notifier.dart';

/// Result of a turn: the latest assistant turn, plus a [pending] action when
/// Ada is waiting for the user's approval before doing something.
class TurnResult {
  final ChatTurn turn;
  final ProposedAction? pending;
  TurnResult({required this.turn, this.pending});
}

/// The orchestrator. Drives a small loop: ask the brain -> run read tools and
/// feed results back -> stop for approval on write tools -> final reply.
class Agent {
  Brain brain;
  final MemoryStore memory;
  final SessionStore session;
  final Notifier notifier;
  final Connectors connectors;
  Persona persona;
  final List<ChatTurn> history = [];

  Agent({
    required this.brain,
    required this.memory,
    required this.session,
    required this.notifier,
    required this.connectors,
    this.persona = const Persona(),
  });

  Future<void> restore() async {
    final saved = await session.load();
    history
      ..clear()
      ..addAll(saved);
  }

  void setBrain(Brain newBrain) => brain = newBrain;
  void setPersona(Persona newPersona) => persona = newPersona;

  Future<BrainResponse> _respond() => brain.respond(
        history: history,
        memoryContext: memory.buildContext(),
        personaInstruction: persona.toInstruction(),
        toolCatalog: toolCatalog,
      );

  ChatTurn _toTurn(BrainResponse r) => ChatTurn(
        role: Role.assistant,
        text: r.reply,
        uncertain: r.uncertain,
        uncertaintyNote: r.uncertaintyNote,
      );

  Future<TurnResult> send(String userText) async {
    history.add(ChatTurn(role: Role.user, text: userText));
    return _drive();
  }

  /// Run after the user approves a proposed write action.
  Future<TurnResult> approve(ProposedAction action) async {
    final result = await runTool(action, connectors);
    history.add(ChatTurn(role: Role.tool, text: '${action.name} -> $result'));
    await session.save(history);
    return _drive();
  }

  /// Run after the user declines a proposed write action.
  Future<TurnResult> decline(ProposedAction action) async {
    history.add(ChatTurn(
      role: Role.tool,
      text: '${action.name} -> the user DECLINED; it was not performed.',
    ));
    await session.save(history);
    return _drive();
  }

  Future<TurnResult> _drive() async {
    var guard = 0;
    while (guard++ < 5) {
      final resp = await _respond();
      final action = resp.action;

      // No tool, or a tool we don't recognise -> final reply.
      if (action == null || !isKnownTool(action.name)) {
        final turn = _toTurn(resp);
        history.add(turn);
        await memory.learn(resp.remember);
        await session.save(history);
        return TurnResult(turn: turn);
      }

      // Write/sensitive tool -> propose and wait for approval.
      if (requiresApproval(action.name)) {
        final say = resp.reply.trim().isEmpty
            ? "I've prepared this. Approve it and I'll go ahead."
            : resp.reply;
        final turn = ChatTurn(role: Role.assistant, text: say, pendingAction: action);
        history.add(turn);
        await memory.learn(resp.remember);
        await session.save(history);
        return TurnResult(turn: turn, pending: action);
      }

      // Read tool -> announce, run, feed result back, loop.
      final say = resp.reply.trim().isEmpty ? 'One moment…' : resp.reply;
      history.add(ChatTurn(role: Role.assistant, text: say));
      final result = await runTool(action, connectors);
      history.add(ChatTurn(role: Role.tool, text: '${action.name} -> $result'));
      await session.save(history);
    }

    final t = ChatTurn(
      role: Role.assistant,
      text: "I had trouble completing that — could you rephrase?",
    );
    history.add(t);
    await session.save(history);
    return TurnResult(turn: t);
  }

  /// Proactive ping hook — call from a scheduler/trigger in a later phase.
  Future<void> ping(String title, String body) => notifier.popup(title, body);

  List<MemoryItem> get knownFacts => memory.all;
}
