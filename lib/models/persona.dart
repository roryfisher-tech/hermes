/// The agent's identity and character. This shapes *how* Hermes speaks — it is
/// deliberately kept separate from the user's memory, and (see ClaudeBrain) it
/// never overrides the accuracy/honesty rules.
class Persona {
  final String name;
  final String gender;       // "Female" | "Male" | "Non-binary" | "Unspecified" | custom
  final String pronouns;     // e.g. "she/her"
  final int age;             // approximate age; shapes voice & word choice
  final String personality;  // freeform description of character & tone
  final bool voiceEnabled;   // read replies aloud

  const Persona({
    this.name = 'Ada',
    this.gender = 'Female',
    this.pronouns = 'she/her',
    this.age = 35,
    this.personality =
        'Helpful, warm, and concise. Honest above all — flags uncertainty plainly.',
    this.voiceEnabled = true,
  });

  /// Sensible default pronouns for a gender label.
  static String pronounsFor(String gender) {
    switch (gender.toLowerCase()) {
      case 'female':
        return 'she/her';
      case 'male':
        return 'he/him';
      case 'non-binary':
        return 'they/them';
      default:
        return 'they/them';
    }
  }

  /// A natural noun for the gender label, used in the prompt.
  String get _genderNoun {
    switch (gender.toLowerCase()) {
      case 'female':
        return 'a woman';
      case 'male':
        return 'a man';
      case 'non-binary':
        return 'a non-binary person';
      default:
        return 'a person';
    }
  }

  /// The block injected into the system prompt.
  String toInstruction() {
    return 'You are $name, a personal assistant dedicated to ONE specific user. '
        'You present as $_genderNoun, around $age years old (pronouns: $pronouns). '
        'Personality and voice: $personality '
        'Stay consistently in this character in tone and word choice.';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'pronouns': pronouns,
        'age': age,
        'personality': personality,
        'voiceEnabled': voiceEnabled,
      };

  factory Persona.fromJson(Map<String, dynamic> j) => Persona(
        name: (j['name'] ?? 'Ada').toString(),
        gender: (j['gender'] ?? 'Female').toString(),
        pronouns: (j['pronouns'] ?? 'she/her').toString(),
        age: (j['age'] is int)
            ? j['age'] as int
            : int.tryParse('${j['age']}') ?? 35,
        personality:
            (j['personality'] ?? const Persona().personality).toString(),
        voiceEnabled: j['voiceEnabled'] != false,
      );

  Persona copyWith({
    String? name,
    String? gender,
    String? pronouns,
    int? age,
    String? personality,
    bool? voiceEnabled,
  }) =>
      Persona(
        name: name ?? this.name,
        gender: gender ?? this.gender,
        pronouns: pronouns ?? this.pronouns,
        age: age ?? this.age,
        personality: personality ?? this.personality,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      );

  /// Quick-start character presets the user can tweak.
  static const List<MapEntry<String, String>> presets = [
    MapEntry('Warm & encouraging',
        'Warm, supportive, and patient. Encourages without flattery, and is gently honest.'),
    MapEntry('Witty & playful',
        'Playful and quick-witted with light humour, but always clear and never sarcastic about facts.'),
    MapEntry('Calm & professional',
        'Calm, precise, and professional. Measured tone, no fluff, gets to the point.'),
    MapEntry('Direct & no-nonsense',
        'Blunt and efficient. Skips pleasantries, states things plainly, respects your time.'),
  ];
}
