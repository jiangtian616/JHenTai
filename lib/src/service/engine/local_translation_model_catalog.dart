import 'model_catalog.dart';

/// The executable GGUF allow-list. Every entry has an authoritative model
/// page, a pinned artifact URL and a SHA-256. Rounded upstream sizes are kept
/// as [ModelArtifactDescriptor.sizeLabel]; the downloader resolves exact bytes
/// from the response before reserving space and installing the file.
class LocalTranslationModelCatalog extends ModelCatalog {
  static const String defaultModelId = 'qwen35-0.8b-q4-k-m';

  LocalTranslationModelCatalog({List<ModelDescriptor>? models})
    : _models = models ?? _verifiedModels;

  final List<ModelDescriptor> _models;

  @override
  List<ModelDescriptor> get models => _models;

  static const List<ModelDescriptor> _verifiedModels = <ModelDescriptor>[
    ModelDescriptor(
      id: 'qwen35-0.8b-q4-k-m',
      kind: 'translation',
      version: 'Qwen3.5-0.8B@167243f/Q4_K_M',
      displayName: 'Qwen3.5 0.8B · Q4_K_M',
      description:
          'Text-only GGUF quantization from the bartowski repository; no image projector is advertised.',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://hf-mirror.com/Qwen/Qwen3.5-0.8B/blob/main/LICENSE',
      sourceProjectUrl:
          'https://hf-mirror.com/bartowski/Qwen_Qwen3.5-0.8B-GGUF',
      quantization: 'Q4_K_M',
      languages: <String>['Multilingual (model card)'],
      supportsImages: false,
      minimumMemoryHint: '约 1 GB；实际取决于上下文和后端',
      runtimeRequirements: <String>[
        'llama.cpp with Qwen3.5 support (at or after fc0fe40)',
        'llama-server on desktop or the maintained JHenTai FFI bridge on mobile',
      ],
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'qwen35-0.8b-q4-k-m',
          fileName: 'Qwen_Qwen3.5-0.8B-Q4_K_M.gguf',
          sizeBytes: 0,
          sizeLabel: '580 MB (upstream rounded display)',
          sha256:
              'fb044e93939a70469c905781334f5de1e6c8b608ced6cbc8c9249bd4127d9526',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/bartowski/Qwen_Qwen3.5-0.8B-GGUF/resolve/167243f/Qwen_Qwen3.5-0.8B-Q4_K_M.gguf?download=true',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation', 'llama-ffi-translation'],
    ),
    ModelDescriptor(
      id: 'hy-mt2-1.8b-q4-k-m',
      kind: 'translation',
      version: 'Hy-MT2-1.8B@1cd5208/Q4_K_M',
      displayName: 'Hy-MT2 1.8B · Q4_K_M',
      description:
          'Tencent official multilingual translation GGUF. The model card documents the llama.cpp Q4_K_M path.',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://hf-mirror.com/tencent/Hy-MT2-1.8B-GGUF',
      sourceProjectUrl: 'https://github.com/Tencent-Hunyuan/Hy-MT2',
      quantization: 'Q4_K_M',
      languages: <String>['Multilingual (official model card list)'],
      supportsImages: false,
      minimumMemoryHint: '约 2 GB；实际取决于上下文和后端',
      runtimeRequirements: <String>[
        'llama.cpp Q4_K_M support',
        'Tokenizer vocabulary must be accepted from the GGUF at load time',
      ],
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'hy-mt2-1.8b-q4-k-m',
          fileName: 'Hy-MT2-1.8B-Q4_K_M.gguf',
          sizeBytes: 0,
          sizeLabel: '1.13 GB (upstream rounded display)',
          sha256:
              'dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/tencent/Hy-MT2-1.8B-GGUF/resolve/1cd5208/Hy-MT2-1.8B-Q4_K_M.gguf?download=true',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation', 'llama-ffi-translation'],
    ),
    ModelDescriptor(
      id: 'qwen35-2b-hauhaucs-aggressive-q4-k-m',
      kind: 'translation',
      version: 'Qwen3.5-2B-Uncensored-HauhauCS-Aggressive@cafbddc/Q4_K_M',
      displayName: 'Qwen3.5 2B Uncensored · Q4_K_M',
      description:
          'HauhauCS Q4 GGUF with an explicitly published F16 image projector; image execution is gated on both files.',
      licenseName: 'Apache-2.0',
      licenseUrl:
          'https://hf-mirror.com/HauhauCS/Qwen3.5-2B-Uncensored-HauhauCS-Aggressive',
      sourceProjectUrl:
          'https://hf-mirror.com/HauhauCS/Qwen3.5-2B-Uncensored-HauhauCS-Aggressive',
      quantization: 'Q4_K_M + projector F16',
      languages: <String>['English', '中文', 'Multilingual (model card tags)'],
      supportsImages: true,
      minimumMemoryHint: '约 3 GB；图片模式还需 projector 和额外上下文内存',
      imageProjectorArtifactId: 'mmproj-f16',
      runtimeRequirements: <String>[
        'llama.cpp multimodal support with --mmproj',
        'Both the main GGUF and mmproj GGUF must pass SHA-256 validation',
      ],
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'qwen35-2b-hauhaucs-aggressive-q4-k-m',
          fileName: 'Qwen3.5-2B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf',
          sizeBytes: 0,
          sizeLabel: '1.27 GB (upstream rounded display)',
          sha256:
              'be3ccca13a9d1bc8b67165ea80bd103cd6151a37ad131183cc7ca388f78d9517',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/HauhauCS/Qwen3.5-2B-Uncensored-HauhauCS-Aggressive/resolve/cafbddc/Qwen3.5-2B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf?download=true',
            ),
          ],
        ),
        ModelArtifactDescriptor(
          id: 'mmproj-f16',
          fileName: 'mmproj-Qwen3.5-2B-Uncensored-HauhauCS-Aggressive-f16.gguf',
          sizeBytes: 0,
          sizeLabel: '668 MB (upstream rounded display)',
          sha256:
              'a86ac75fbd9a11d1883c688969d88a11d3d24a729cc7e181833fd2e1b3865c9d',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/HauhauCS/Qwen3.5-2B-Uncensored-HauhauCS-Aggressive/resolve/cafbddc/mmproj-Qwen3.5-2B-Uncensored-HauhauCS-Aggressive-f16.gguf?download=true',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation', 'llama-ffi-translation'],
    ),
    ModelDescriptor(
      id: 'qwen35-4b-hauhaucs-aggressive-q4-k-m',
      kind: 'translation',
      version: 'Qwen3.5-4B-Uncensored-HauhauCS-Aggressive@55e05ab/Q4_K_M',
      displayName: 'Qwen3.5 4B Uncensored · Q4_K_M',
      description:
          'HauhauCS Q4 GGUF with an explicitly published BF16 image projector; image execution is gated on both files.',
      licenseName: 'Apache-2.0',
      licenseUrl:
          'https://hf-mirror.com/HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive',
      sourceProjectUrl:
          'https://hf-mirror.com/HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive',
      quantization: 'Q4_K_M + projector BF16',
      languages: <String>['English', '中文', 'Multilingual (model card tags)'],
      supportsImages: true,
      minimumMemoryHint: '约 5 GB；图片模式还需 projector 和额外上下文内存',
      imageProjectorArtifactId: 'mmproj-bf16',
      runtimeRequirements: <String>[
        'llama.cpp multimodal support with --mmproj',
        'Both the main GGUF and mmproj GGUF must pass SHA-256 validation',
      ],
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'qwen35-4b-hauhaucs-aggressive-q4-k-m',
          fileName: 'Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf',
          sizeBytes: 0,
          sizeLabel: '2.71 GB (upstream rounded display)',
          sha256:
              '79e28ecacf84e75b6056cf4059636d435aa9eb67795780f7b7dbc7d32a962741',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive/resolve/55e05ab/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf?download=true',
            ),
          ],
        ),
        ModelArtifactDescriptor(
          id: 'mmproj-bf16',
          fileName:
              'mmproj-Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-BF16.gguf',
          sizeBytes: 0,
          sizeLabel: '676 MB (upstream rounded display)',
          sha256:
              'a1e32e86ea99aa7a56f3dcfe7e63c1d0be9439d31fd07087099f15bc0fda0f22',
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'hf-mirror-pinned',
              url:
                  'https://hf-mirror.com/HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive/resolve/c124469/mmproj-Qwen3.5-4B-Uncensored-HauhauCS-Aggressive-BF16.gguf?download=true',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation', 'llama-ffi-translation'],
    ),
  ];

  /// Audited but intentionally excluded from the executable catalog. The
  /// official model cards point to llama.cpp PR #19357 for the Tencent STQ
  /// format, and that PR is still Draft/unmerged at the pinned runtime.
  static const List<ExcludedLocalTranslationArtifact>
  excludedArtifacts = <ExcludedLocalTranslationArtifact>[
    ExcludedLocalTranslationArtifact(
      id: 'hy-mt2-1.8b-2bit',
      modelUrl: 'https://hf-mirror.com/tencent/Hy-MT2-1.8B-2Bit-GGUF',
      artifactUrl:
          'https://hf-mirror.com/tencent/Hy-MT2-1.8B-2Bit-GGUF/blob/main/Hy-MT2-1.8B-2Bit.gguf',
      sha256:
          'dcc33bbae9b28d923c8c76a64f6157840841d26f8774f3dfd770d5fabeeb1cd7',
      reason:
          'Official card requires STQ/Q2_0C work from llama.cpp PR #19357, still Draft/unmerged.',
    ),
    ExcludedLocalTranslationArtifact(
      id: 'hy-mt2-1.8b-1.25bit',
      modelUrl: 'https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF',
      artifactUrl:
          'https://hf-mirror.com/tencent/Hy-MT2-1.8B-1.25Bit-GGUF/blob/main/Hy-MT2-1.8B-1.25Bit.gguf',
      sha256:
          'cc497fe8f033b52b3b8b00a7669e9661435432f9d4cd43f7ed24400c01507a93',
      reason:
          'The official low-bit card does not provide a merged stable llama.cpp runtime path; STQ support remains blocked by PR #19357.',
    ),
  ];
}

class ExcludedLocalTranslationArtifact {
  const ExcludedLocalTranslationArtifact({
    required this.id,
    required this.modelUrl,
    required this.artifactUrl,
    required this.sha256,
    required this.reason,
  });

  final String id;
  final String modelUrl;
  final String artifactUrl;
  final String sha256;
  final String reason;
}
