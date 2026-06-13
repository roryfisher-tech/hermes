/// Voice (text-to-speech) is temporarily DISABLED.
///
/// The flutter_tts plugin needs extra native build setup on Windows desktop,
/// so it's stubbed out to keep desktop builds simple. The rest of the app still
/// calls these methods — they're now harmless no-ops.
///
/// To bring the spoken voice back (easiest on Android): re-add `flutter_tts` to
/// pubspec.yaml and restore the real implementation (see project history /
/// CONNECT context), then rebuild.
class VoiceService {
  String language = 'en-GB';
  double pitch = 1.0;
  double rate = 0.5;

  Future<void> init() async {}

  Future<void> applyTuning({double? newPitch, double? newRate}) async {
    if (newPitch != null) pitch = newPitch;
    if (newRate != null) rate = newRate;
  }

  Future<void> speak(String text) async {}

  Future<void> stop() async {}
}
