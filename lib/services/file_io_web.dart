import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> pickCsvImpl() async {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    // Accept extensions and standard MIME types so mobile Safari/Chrome never grays out files
    ..accept = '.csv,.txt,text/csv,text/plain,application/vnd.ms-excel,text/comma-separated-values,*/*'
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.opacity = '0';

  web.document.body?.appendChild(input);

  input.addEventListener('change', ((web.Event e) {
    final files = input.files;
    if (files != null && files.length > 0) {
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.addEventListener('loadend', ((web.Event _) {
        final result = reader.result;
        String? text;
        if (result != null) {
          if (result.isA<JSArrayBuffer>()) {
            final buffer = (result as JSArrayBuffer).toDart;
            final bytes = buffer.asUint8List();
            text = utf8.decode(bytes, allowMalformed: true);
          } else {
            text = (result as JSString).toDart;
          }
          if (text.startsWith('\uFEFF')) {
            text = text.substring(1);
          }
        }
        input.remove();
        if (!completer.isCompleted) {
          completer.complete(text);
        }
      }).toJS);

      reader.addEventListener('error', ((web.Event _) {
        input.remove();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS);

      reader.readAsArrayBuffer(file);
    } else {
      input.remove();
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  }).toJS);

  input.addEventListener('cancel', ((web.Event _) {
    input.remove();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }).toJS);

  input.click();
  return completer.future;
}

Future<void> saveCsvImpl({required String baseName, required String csv}) async {
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = '$baseName.csv'
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
