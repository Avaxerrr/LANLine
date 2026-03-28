import 'package:path/path.dart' as p;

String guessAttachmentKind(String fileName, String? mimeType) {
  final ext = p.extension(fileName).toLowerCase();
  if ((mimeType?.startsWith('image/') ?? false) ||
      {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
        '.svg',
      }.contains(ext)) {
    return 'image';
  }
  if ((mimeType?.startsWith('audio/') ?? false) ||
      {'.mp3', '.m4a', '.wav', '.ogg', '.aac', '.flac'}.contains(ext)) {
    return 'audio';
  }
  if ((mimeType?.startsWith('video/') ?? false) ||
      {'.mp4', '.mov', '.mkv', '.avi', '.webm'}.contains(ext)) {
    return 'video';
  }
  return 'file';
}

String? guessMimeType(String fileName) {
  switch (p.extension(fileName).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.bmp':
      return 'image/bmp';
    case '.svg':
      return 'image/svg+xml';
    case '.mp3':
      return 'audio/mpeg';
    case '.m4a':
      return 'audio/mp4';
    case '.wav':
      return 'audio/wav';
    case '.ogg':
      return 'audio/ogg';
    case '.flac':
      return 'audio/flac';
    case '.aac':
      return 'audio/aac';
    case '.mp4':
      return 'video/mp4';
    case '.mov':
      return 'video/quicktime';
    case '.mkv':
      return 'video/x-matroska';
    case '.avi':
      return 'video/x-msvideo';
    case '.webm':
      return 'video/webm';
    case '.pdf':
      return 'application/pdf';
    case '.txt':
      return 'text/plain';
    case '.json':
      return 'application/json';
    case '.csv':
      return 'text/csv';
    case '.zip':
      return 'application/zip';
    default:
      return null;
  }
}
