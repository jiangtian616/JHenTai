import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';
import 'package:test/test.dart';

import 'package:jhentai/src/service/engine/engine_contract.dart';
import 'package:jhentai/src/service/engine/llama_cpp_ffi_engine.dart';

class _CpuPlatform extends LibLlamaCppPlatform {
  @override
  Future<LlamaCppLibraryDescriptor> resolveLibrary({
    LlamaCppLibraryRequest request = const LlamaCppLibraryRequest(),
  }) async {
    return const LlamaCppLibraryDescriptor(
      resolution: LlamaCppLibraryResolution.lookupName,
      lookupName: 'lib_llama_cpp_test.so',
      capabilities: <LlamaCppLibraryCapability>{LlamaCppLibraryCapability.cpu},
    );
  }
}

class _FailingPlatform extends LibLlamaCppPlatform {
  @override
  Future<LlamaCppLibraryDescriptor> resolveLibrary({
    LlamaCppLibraryRequest request = const LlamaCppLibraryRequest(),
  }) {
    throw UnsupportedError('native library missing');
  }
}

void main() {
  test('native runtime is ready only after a CPU library resolves', () async {
    final LibLlamaCppRuntime runtime = LibLlamaCppRuntime(
      platform: _CpuPlatform(),
    );

    expect(runtime.isAvailable, isFalse);
    expect(await runtime.ensureAvailable(), isTrue);
    expect(runtime.isAvailable, isTrue);
  });

  test('native runtime does not report ready when resolution fails', () async {
    final LibLlamaCppRuntime runtime = LibLlamaCppRuntime(
      platform: _FailingPlatform(),
    );

    expect(await runtime.ensureAvailable(), isFalse);
    expect(runtime.isAvailable, isFalse);
  });

  test('local GGUF adapter exposes one contract on every native target', () {
    final LlamaCppFfiTranslationEngine engine = LlamaCppFfiTranslationEngine();

    expect(
      engine.descriptor.platforms,
      containsAll(<EnginePlatform>{
        EnginePlatform.android,
        EnginePlatform.ios,
        EnginePlatform.linux,
        EnginePlatform.macos,
        EnginePlatform.windows,
      }),
    );
  });
}
