import 'speech_service.dart';

SpeechService getSpeechService() => SpeechServiceStub();

class SpeechServiceStub implements SpeechService {
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> startListening({
    required Function(String text) onResult,
    required void Function() onEnd,
    required Function(String error) onError,
  }) async {
    _isListening = false;
    onError('Perekaman suara via mikrofon browser hanya aktif di PWA/Web.');
    onEnd();
    return false;
  }

  @override
  void stopListening() {
    _isListening = false;
  }
}
