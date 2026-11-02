import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'api_client.dart' show ApiException;

/// A video the creator picked for an episode.
class PickedVideo {
  const PickedVideo({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef VideoPicker = Future<List<PickedVideo>> Function();

/// The server refuses anything larger, so say so before sending it.
const maxVideoBytes = 200 * 1024 * 1024;

/// All the videos of one upload together; keeps memory use bounded.
const maxTotalVideoBytes = 600 * 1024 * 1024;

/// Throws before anything is read when one video, or all of them together, are
/// larger than the server (and this app) accept.
void checkVideoSizes(List<int> sizes) {
  if (sizes.any((size) => size > maxVideoBytes)) {
    throw const ApiException(
      code: 'FILE_TOO_LARGE',
      message: 'Each video must be 200 MB or less.',
    );
  }
  if (sizes.fold<int>(0, (sum, size) => sum + size) > maxTotalVideoBytes) {
    throw const ApiException(
      code: 'FILE_TOO_LARGE',
      message: 'Choose videos totalling 600 MB or less at a time.',
    );
  }
}

/// Opens the device's file picker for videos. Empty when the person cancels.
Future<List<PickedVideo>> pickVideosFromDevice() async {
  final files = await FilePicker.pickFiles(type: FileType.video);
  // Sizes come from the picker's metadata, so a file that is too large is
  // refused before any of its bytes are read into memory.
  checkVideoSizes([for (final file in files) await file.length() ?? 0]);
  return [
    for (final file in files)
      PickedVideo(name: file.name, bytes: await file.readAsBytes()),
  ];
}
