import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// mock web File
/// no implement
// ignore_for_file: always_specify_types,avoid_unused_constructor_parameters,unused_field
class File {
  /// Creates a [File] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [Directory.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  ///

  File(this.path) : assert(false, 'not support on web');

  /// Reads the entire file contents as a list of bytes.
  ///
  /// Returns a `Future<Uint8List>` that completes with the list of bytes that
  /// is the contents of the file.
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(<int>[]);

  /// The path of the file underlying this random access file.
  final String path;
}

/// mock web File
/// no implement
class FileImage extends ImageProvider<FileImage> {
  /// Creates an object that decodes a [File] as an image.
  ///
  /// The arguments must not be null.
  const FileImage(this.file, {this.scale = 1.0});

  /// The file to decode into an image.
  final File file;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  Future<FileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FileImage>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FileImage &&
        other.file.path == file.path &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(file.path, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'FileImage')}("${file.path}", scale: $scale)';
}
