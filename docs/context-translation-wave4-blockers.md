# Wave 4 context translation boundary

## Verified in this change

- `ContextTranslationEngine` requires one structured request containing the
  selected pages and requires returned `pageId`/`lineId` pairs.
- The service rejects unknown, duplicate, missing, and empty line mappings. It
  never falls back to response order or concatenated text.
- `ContextBatchSize` exposes only `1`, `2`, `4`, and `8` pages.
- Each page is published and persisted independently under a cache key that
  includes ordered context page hashes, batch size, model version, prompt
  version, target/source language, and OCR configuration.
- Existing `ImageTranslationService` gzip persistence, hydrate, overlay result
  publication, batch progress, and cancellation surfaces are reused.

## Explicit blockers

- No existing engine on the `d65c9108` baseline implements
  `ContextTranslationEngine`. The registry deliberately does not treat a
  single-page `TranslationEngine` as context-capable.
- The current read-page UI still invokes the existing single-page loop. A UI
  selector and production wiring require a verified engine adapter first.
- No real provider/model API smoke was run. The API and local GGUF runtimes
  were not modified in this branch. In particular, the current llama.cpp FFI
  and llama-server adapters have no verified structured context request and
  response contract.
- The structured-output references checked for a future adapter are:
  - OpenAI API response formats: https://platform.openai.com/docs/api-reference
  - DeepSeek JSON Output: https://api-docs.deepseek.com/guides/json_mode/
  - Anthropic tool schemas: https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
  These documents support structured JSON/tool schemas, but do not prove that
  every user-configured endpoint or local model supports the same contract.

## Migration and rollback

No database or existing cache format is changed. Context results use a new
`context-translation-v1` namespace and leave ordinary per-page translation
entries untouched. Reverting this commit removes the new service/contract and
leaves old translation caches readable; newly created context files can be
deleted as derived cache data.

## Verification boundary

`test/context_translation_service_test.dart` runs on the Dart/Flutter host and
uses a deterministic fake structured engine. It does not claim API, llama.cpp,
iOS, Android, Windows, or Linux model execution. Those remain follow-up work
after a concrete engine adapter and its authoritative request/response
contract are selected.
