import '../connectors/models.dart';

/// A single turn in the conversation. Kept tiny and serialisable so it can be
/// persisted or sent to the brain as history.
///
/// Role.tool carries a tool result; it is hidden in the UI and mapped to a
/// user message for the API (which only knows user/assistant).
enum Role { user, assistant, tool }

class ChatTurn {
  final Role role;
  final String text;
  final bool uncertain;
  final String uncertaintyNote;
  final DateTime at;

  /// When set, this assistant turn is awaiting the user's approval for a
  /// write action. Transient (not persisted) so stale prompts never linger.
  ProposedAction? pendingAction;

  ChatTurn({
    required this.role,
    required this.text,
    this.uncertain = false,
    this.uncertaintyNote = '',
    this.pendingAction,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  /// Shape the brain expects for prior turns (tool results go in as user text).
  Map<String, String> toApiMessage() => {
        'role': role == Role.assistant ? 'assistant' : 'user',
        'content': role == Role.tool ? 'TOOL RESULT:\n$text' : text,
      };

  /// Persistence (saved session).
  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'uncertain': uncertain,
        'uncertaintyNote': uncertaintyNote,
        'at': at.toIso8601String(),
      };

  factory ChatTurn.fromJson(Map<String, dynamic> j) => ChatTurn(
        role: switch (j['role']) {
          'assistant' => Role.assistant,
          'tool' => Role.tool,
          _ => Role.user,
        },
        text: (j['text'] ?? '').toString(),
        uncertain: j['uncertain'] == true,
        uncertaintyNote: (j['uncertaintyNote'] ?? '').toString(),
        at: DateTime.tryParse((j['at'] ?? '').toString()),
      );
}
