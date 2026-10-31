import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A video the creator picked for an episode.
class PickedVideo {
  const PickedVideo({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef VideoPicker = Future<List<PickedVideo>> Function();

/// The server refuses anything larger, so say so before sending it.
const maxVideoBytes = 200 * 1024 * 1024;

/// Opens the device's file picker for videos. Empty when the person cancels.
Future<List<PickedVideo>> pickVideosFromDevice() async {
  final files = await FilePicker.pickFiles(type: FileType.video);
  return [
    for (final file in files)
      PickedVideo(name: file.name, bytes: await file.readAsBytes()),
  ];
}
