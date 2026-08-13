// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

class OrtModelMetadata {
  final String producerName;
  final String graphName;
  final String domain;
  final String description;
  final int version;
  final Map<String, String> customMetadataMap;

  OrtModelMetadata({
    required this.producerName,
    required this.graphName,
    required this.domain,
    required this.description,
    required this.version,
    required this.customMetadataMap,
  });

  factory OrtModelMetadata.fromMap(Map<String, dynamic> map) {
    return OrtModelMetadata(
      producerName: map['producerName'] as String? ?? '',
      graphName: map['graphName'] as String? ?? '',
      domain: map['domain'] as String? ?? '',
      description: map['description'] as String? ?? '',
      version: map['version'] as int? ?? 0,
      customMetadataMap: Map<String, String>.from(map['customMetadataMap'] ?? {}),
    );
  }

  /// Converts the metadata to a Map
  ///
  /// Returns a map representation of the model metadata
  Map<String, dynamic> toMap() {
    return {
      'producerName': producerName,
      'graphName': graphName,
      'domain': domain,
      'description': description,
      'version': version,
      'customMetadataMap': customMetadataMap,
    };
  }
}
