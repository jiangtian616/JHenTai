import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';

void main() {
  test('PP-OCRv6 manifest is complete and only advertises real mirrors', () {
    final OnnxModelManifest manifest = OnnxModelStore.manifests.singleWhere(
      (OnnxModelManifest item) => item.id == OnnxModelStore.ocrManifestId,
    );

    expect(manifest.displayName, contains('PP-OCRv6'));
    expect(
      manifest.files.map((OnnxModelFile file) => file.id),
      containsAll(<String>['det', 'rec', 'cls', 'dict']),
    );
    expect(manifest.availableSources, <OnnxModelSource>[
      OnnxModelSource.modelScope,
    ]);
    expect(manifest.totalBytes, 31824456);
    expect(manifest.fingerprint, contains(manifest.version));

    for (final OnnxModelFile file in manifest.files) {
      expect(file.sha256, hasLength(64));
      expect(file.sizeBytes, greaterThan(0));
      expect(file.urls.keys, containsAll(manifest.availableSources));
      expect(file.urls.values, everyElement(startsWith('https://')));
    }
  });

  test('PP-OCRv6 tiny manifest uses its reduced dictionary and verified files',
      () {
    final OnnxModelManifest manifest = OnnxModelStore.manifests.singleWhere(
      (OnnxModelManifest item) => item.id == OnnxModelStore.ocrTinyManifestId,
    );

    expect(manifest.displayName, contains('tiny'));
    expect(
      manifest.files.map((OnnxModelFile file) => file.id),
      containsAll(<String>['det', 'rec', 'cls', 'dict']),
    );
    expect(manifest.availableSources, <OnnxModelSource>[
      OnnxModelSource.modelScope,
    ]);
    // The tiny tier reuses the shared PP-OCRv4 cls model but ships its own
    // reduced dictionary (27 KB vs the small tier's 75 KB).
    expect(
      manifest.files.singleWhere((OnnxModelFile f) => f.id == 'dict').fileName,
      'ppocrv6_tiny_dict.txt',
    );
    // Verified by downloading each file and hashing it (see the manifest).
    expect(manifest.totalBytes, 1829618 + 4489813 + 585532 + 27156);
    expect(
      manifest.files.singleWhere((OnnxModelFile f) => f.id == 'det').sha256,
      'f42c0fbd294d95eac1a550e131b277dac97462c8025fa4b6c3cec1b7894bd3d5',
    );
    expect(
      manifest.files.singleWhere((OnnxModelFile f) => f.id == 'rec').sha256,
      'e16e242de5937ad92609223f19bc2aff3727ee40b095f996907c24749bad251b',
    );
    expect(
      manifest.files.singleWhere((OnnxModelFile f) => f.id == 'dict').sha256,
      'c5cbe34ef40c29c4df07ed012bf96569cb69a2d2a01a07027e9f13cb832bd9cd',
    );
    for (final OnnxModelFile file in manifest.files) {
      expect(file.sha256, hasLength(64));
      expect(file.sizeBytes, greaterThan(0));
      expect(file.urls.keys, containsAll(manifest.availableSources));
      expect(file.urls.values, everyElement(startsWith('https://')));
    }
  });

  test('Real-ESRGAN manifest advertises its reachable hosts only', () {
    final OnnxModelManifest manifest = OnnxModelStore.manifests.singleWhere(
      (OnnxModelManifest item) =>
          item.id == OnnxModelStore.superResolutionManifestId,
    );

    // ModelScope is the default download source (first in the enum); the
    // byte-identical HuggingFace copy stays as a fallback.
    expect(manifest.availableSources, <OnnxModelSource>[
      OnnxModelSource.modelScope,
      OnnxModelSource.huggingFace,
    ]);
    expect(manifest.files, hasLength(1));
    expect(manifest.files.single.sizeBytes, 17906556);
    expect(manifest.files.single.sha256, hasLength(64));
    expect(
      manifest.files.single.urls[OnnxModelSource.modelScope],
      startsWith('https://www.modelscope.cn/'),
    );
  });

  test('lighter 4B32F super-resolution manifest is a verified drop-in', () {
    final OnnxModelManifest manifest = OnnxModelStore.manifests.singleWhere(
      (OnnxModelManifest item) =>
          item.id == OnnxModelStore.superResolutionFastManifestId,
    );

    expect(manifest.kind, 'superResolution');
    expect(manifest.availableSources, <OnnxModelSource>[
      OnnxModelSource.modelScope,
      OnnxModelSource.huggingFace,
    ]);
    expect(manifest.files, hasLength(1));
    // Verified by download + SHA-256 (identical bytes on ModelScope and HF).
    expect(manifest.files.single.sizeBytes, 5156099);
    expect(
      manifest.files.single.sha256,
      '2208c7ae8db793330abf1248fbce15585ad317e921c456265572836b92926c9a',
    );

    // Both SR manifests are the same x4 contract, so a picker listing
    // manifestsOfKind('superResolution') offers exactly the two models.
    expect(
      OnnxModelStore.instance
          .manifestsOfKind('superResolution')
          .map((OnnxModelManifest item) => item.id),
      containsAll(<String>[
        OnnxModelStore.superResolutionManifestId,
        OnnxModelStore.superResolutionFastManifestId,
      ]),
    );
  });
}
