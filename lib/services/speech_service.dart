import 'speech_service_stub.dart'
    if (dart.library.js_interop) 'speech_service_web.dart';

abstract class SpeechService {
  static final SpeechService instance = getSpeechService();

  bool get isListening;
  Future<bool> startListening({
    required Function(String text) onResult,
    required void Function() onEnd,
    required Function(String error) onError,
  });
  void stopListening();
}
