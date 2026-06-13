import '../models/chat_turn.dart';
import '../models/memory_item.dart';

/// The swappable "brain". Today it's Claude Opus 4.8; tomorrow it could be a
/// self-hosted or on-device model. The rest of the app only talks to this
/// interface, so swapping the backend never touches the agent, memory, or UI.
abstract class Brain {
  /// A short label for settings/debug (e.g. "Claude Opus 4.8").
  String get name;

  /// Produce a response given the full conversation [history] (which already
  /// ends with the latest user or tool-result turn), plus the on-device memory,
  /// persona, and the catalog of tools the agent can run.
  Future<BrainResponse> respond({
    required List<ChatTurn> history,
    String memoryContext = '',
    String personaInstruction = '',
    String toolCatalog = '',
  });
}
