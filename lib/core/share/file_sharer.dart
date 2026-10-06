import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the phone's share sheet (Drive, e-mail, WhatsApp,
/// save to files...). It is an interface so tests never touch the platform.
abstract class FileSharer {
  Future<void> shareFile({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  });
}

class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> shareFile({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)],
        // The name of a file made from data is ignored by the plugin on
        // phones, so it is given here (without it the file gets a random name).
        fileNameOverrides: [fileName],
      ),
    );
  }
}