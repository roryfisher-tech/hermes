import '../connectors/models.dart';

/// One durable thing Hermes has learned about the user.
/// Stored on-device only, in JSON.
class MemoryItem {
  final String key;        // e.g. "timezone", "prefers_metric", "job"
  final String value;      // e.g. "Europe/Brussels"
  final String confidence; // "high" | "medium" | "low"
  final DateTime updatedAt;

  MemoryItem({
    required this.key,
    required this.value,
    this.confidence = 'medium',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'value': value,
        'confidence': confidence,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MemoryItem.fromJson(String key, Map<String, dynamic> j) => MemoryItem(
        key: key,
        value: (j['value'] ?? '').toString(),
        confidence: (j['confidence'] ?? 'medium').toString(),
        updatedAt:
            DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// What the brain returns for every turn. Designed to make the agent's
/// requirements first-class: a reply, an explicit honesty signal, the facts
/// worth learning, and (optionally) a tool action to take.
class BrainResponse {
  final String reply;
  final bool uncertain;          // true => the model is not confident
  final String uncertaintyNote;  // why / what to double-check
  final List<MemoryItem> remember;
  final ProposedAction? action;  // a tool the brain wants to use (or null)

  BrainResponse({
    required this.reply,
    this.uncertain = false,
    this.uncertaintyNote = '',
    this.remember = const [],
    this.action,
  });
}
