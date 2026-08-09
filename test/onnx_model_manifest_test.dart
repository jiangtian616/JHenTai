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

  test('Real-ESRGAN manifest advertises its reachable host only', () {
    final OnnxModelManifest manifest = OnnxModelStore.manifests.singleWhere(
      (OnnxModelManifest item) =>
          item.id == OnnxModelStore.superResolutionManifestId,
    );

    expect(manifest.availableSources, <OnnxModelSource>[
      OnnxModelSource.huggingFace,
    ]);
    expect(manifest.files, hasLength(1));
    expect(manifest.files.single.sizeBytes, 17906556);
    expect(manifest.files.single.sha256, hasLength(64));
  });
}
