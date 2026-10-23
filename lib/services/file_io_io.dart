import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';

Future<String?> pickCsvImpl() async {
  final platformFile = await FilePicker.pickFile(
    type: FileType.any,
  );
  if (platformFile == null) return null;

  final bytes = await platformFile.readAsBytes();
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }
  return text;
}

Future<void> saveCsvImpl({required String baseName, required String csv}) async {
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  await FileSaver.instance.saveFile(
    name: baseName,
    bytes: bytes,
    fileExtension: 'csv',
    mimeType: MimeType.csv,
  );
}
