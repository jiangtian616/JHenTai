import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Extract the zip file at [archivePath] to [extractPath].
///
/// Entries are streamed one at a time: only the central directory and a single
/// entry's bytes are held in memory at any moment, instead of the whole
/// archive (ZipDecoder.decodeBuffer keeps every entry's compressed data in
/// memory at once). Extraction first goes to `extractPath + '.tmp'` and the
/// directory is atomically renamed into place only on success; on failure the
/// temp directory is removed.
Future<bool> extractZipArchive(String archivePath, String extractPath) {
  return compute(
    (List<String> path) async {
      final String tmpExtractPath = '${path[1]}.tmp';
      try {
        final Directory tmpDir = Directory(tmpExtractPath);
        if (tmpDir.existsSync()) {
          tmpDir.deleteSync(recursive: true);
        }

        await _streamExtractZip(path[0], tmpExtractPath);

        /// swap the temp dir into place
        final Directory finalDir = Directory(path[1]);
        if (finalDir.existsSync()) {
          finalDir.deleteSync(recursive: true);
        }
        await Directory(tmpExtractPath).rename(path[1]);
        return true;
      } catch (_) {
        try {
          final Directory tmpDir = Directory(tmpExtractPath);
          if (tmpDir.existsSync()) {
            tmpDir.deleteSync(recursive: true);
          }
        } catch (_) {
          // best-effort cleanup
        }
        return false;
      }
    },
    [archivePath, extractPath],
  );
}

/// End of central directory record signature.
const int _eocdSignature = 0x06054b50;

/// Zip64 end of central directory locator signature.
const int _zip64EocdLocatorSignature = 0x07064b50;

/// Max EOCD comment length (2 bytes) + the EOCD record itself.
const int _maxEocdSearchBytes = 65535 + 22;

/// Stream zip entries one at a time from [archivePath] into [extractPath].
Future<void> _streamExtractZip(String archivePath, String extractPath) async {
  final int fileLength = File(archivePath).lengthSync();
  final InputFileStream inputStream = InputFileStream(archivePath);
  try {
    final List<ZipFileHeader> headers = _readCentralDirectory(inputStream, fileLength);
    for (final ZipFileHeader header in headers) {
      inputStream.position = header.localHeaderOffset!;
      final ZipFile zipFile = ZipFile(inputStream, header, null);
      _writeEntryToDisk(zipFile, extractPath);
    }
  } finally {
    inputStream.close();
  }
}

/// Parse the zip's end-of-central-directory record and central directory,
/// returning the file headers without reading any entry content.
List<ZipFileHeader> _readCentralDirectory(InputFileStream inputStream, int fileLength) {
  final int tailLength = fileLength < _maxEocdSearchBytes ? fileLength : _maxEocdSearchBytes;
  inputStream.position = fileLength - tailLength;
  final Uint8List tail = inputStream.readBytes(tailLength).toUint8List();
  final ByteData tailData = ByteData.sublistView(tail);

  int eocdRel = -1;
  for (int i = tailLength - 22; i >= 0; i--) {
    if (tailData.getUint32(i, Endian.little) == _eocdSignature) {
      eocdRel = i;
      break;
    }
  }
  if (eocdRel < 0) {
    throw ArchiveException('Invalid zip: end of central directory record not found');
  }

  int totalEntries = tailData.getUint16(eocdRel + 10, Endian.little);
  int centralDirectorySize = tailData.getUint32(eocdRel + 12, Endian.little);
  int centralDirectoryOffset = tailData.getUint32(eocdRel + 16, Endian.little);

  /// zip64: sentinel values mean the real values live in the zip64 EOCD record
  if (totalEntries == 0xffff || centralDirectorySize == 0xffffffff || centralDirectoryOffset == 0xffffffff) {
    final int locatorRel = eocdRel - 20;
    if (locatorRel >= 0 && tailData.getUint32(locatorRel, Endian.little) == _zip64EocdLocatorSignature) {
      final int zip64EocdOffset = tailData.getUint32(locatorRel + 8, Endian.little);
      inputStream.position = zip64EocdOffset;
      inputStream.readUint32(); // signature
      inputStream.readUint64(); // size of the zip64 EOCD record
      inputStream.readUint16(); // version made by
      inputStream.readUint16(); // version needed to extract
      inputStream.readUint32(); // number of this disk
      inputStream.readUint32(); // disk with start of central directory
      inputStream.readUint64(); // entries on this disk
      totalEntries = inputStream.readUint64();
      inputStream.readUint64(); // central directory size
      centralDirectoryOffset = inputStream.readUint64();
    }
  }

  inputStream.position = centralDirectoryOffset;
  final List<ZipFileHeader> headers = <ZipFileHeader>[];
  final int centralDirectoryEnd = centralDirectoryOffset + centralDirectorySize;
  while (inputStream.position < centralDirectoryEnd) {
    final int signature = inputStream.readUint32();
    if (signature != ZipFileHeader.SIGNATURE) {
      break;
    }
    headers.add(ZipFileHeader(inputStream));
  }
  return headers;
}

/// Write one zip entry to [extractPath], guarding against path traversal.
void _writeEntryToDisk(ZipFile zipFile, String extractPath) {
  final String entryName = zipFile.filename.replaceAll('\\', '/');
  if (entryName.isEmpty) {
    return;
  }
  final String filePath = p.join(extractPath, p.normalize(entryName));
  if (!isWithinOutputPath(extractPath, filePath)) {
    throw ArchiveException('Invalid zip entry path: $entryName');
  }

  if (entryName.endsWith('/')) {
    Directory(filePath).createSync(recursive: true);
    return;
  }

  final File file = File(filePath)..createSync(recursive: true);
  file.writeAsBytesSync(zipFile.content);
}

Future<List<int>> extractGZipArchive(String archivePath) {
  return compute(
    (String path) async {
      InputFileStream inputStream = InputFileStream(path);
      try {
        return GZipDecoder().decodeBuffer(inputStream);
      } on Exception catch (_) {
        return [];
      } finally {
        inputStream.close();
      }
    },
    archivePath,
  );
}
