import 'dart:js_interop';
import 'speech_service.dart';

SpeechService getSpeechService() => SpeechServiceWeb();

@JS('iritotSpeech.start')
external bool _startSpeech(
  JSFunction onResult,
  JSFunction onEnd,
  JSFunction onError,
);

@JS('iritotSpeech.stop')
external void _stopSpeech();

class SpeechServiceWeb implements SpeechService {
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> startListening({
    required Function(String text) onResult,
    required void Function() onEnd,
    required Function(String error) onError,
  }) async {
    try {
      final onResultJS = ((JSString text) {
        onResult(text.toDart);
      }).toJS;

      final onEndJS = (() {
        _isListening = false;
        onEnd();
      }).toJS;

      final onErrorJS = ((JSString err) {
        _isListening = false;
        onError(err.toDart);
      }).toJS;

      final started = _startSpeech(onResultJS, onEndJS, onErrorJS);
      _isListening = started;
      return started;
    } catch (e) {
      _isListening = false;
      onError(e.toString());
      return false;
    }
  }

  @override
  void stopListening() {
    try {
      _stopSpeech();
    } catch (_) {}
    _isListening = false;
  }
}
