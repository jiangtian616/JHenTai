import Foundation
import Vision
import ImageIO
import CoreGraphics
import NaturalLanguage
import Translation

/// Apple Live Text OCR (Vision framework). This file is intentionally free of
/// Flutter / UIKit / AppKit imports so the exact same source compiles in both
/// the iOS and macOS Runner targets. The MethodChannel wiring lives in the
/// per-platform AppDelegate / MainFlutterWindow.
///
/// Contract (invoked as method `recognizeText` on `channelName`):
///   input : { path: String,
///             languages: [String]?,   // BCP-47 codes; empty/nil => auto/OS default
///             automaticallyDetectsLanguage: Bool,
///             recognitionLevel: String?,  // "accurate" (default) | "fast"
///             maxDimension: Int?,          // downscale if the longest edge exceeds this
///             orientationOverride: Int? }  // EXIF 1-8; 0/absent => read from the file
///   output: { width: Double, height: Double,     // original upright pixel size
///             orientation: Int,
///             lines: [ { text, confidence, left, top, width, height } ] }
///   `left/top/width/height` are in TOP-LEFT-origin pixel coordinates of the
///   original upright image (the space Flutter's image translation overlay uses).
enum LiveTextOCR {
  static let channelName = "top.jtmonster.jhentai.live_text_ocr"

  static func run(arguments: [String: Any]) throws -> [String: Any] {
    guard let path = arguments["path"] as? String else {
      throw NSError(domain: "LiveTextOCR", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing 'path'"])
    }
    let url = URL(fileURLWithPath: path)

    // ImageIO so the same code runs on iOS and macOS and we can read EXIF.
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(domain: "LiveTextOCR", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot load image at \(path)"])
    }

    // Orientation: an explicit override wins; otherwise use the file's EXIF tag.
    var orientation = CGImagePropertyOrientation.up
    if let override = arguments["orientationOverride"] as? Int, (1...8).contains(override),
       let ori = CGImagePropertyOrientation(rawValue: UInt32(override)) {
      orientation = ori
    } else if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = props[kCGImagePropertyOrientation] as? UInt32,
              let ori = CGImagePropertyOrientation(rawValue: raw) {
      orientation = ori
    }

    // Original upright pixel dimensions; 90-degree orientations swap width/height.
    let rawSize = CGSize(width: cgImage.width, height: cgImage.height)
    let upright = uprightSize(for: rawSize, orientation: orientation)

    // Optional downscale of large pages. Coordinates stay in the ORIGINAL space
    // because we scale Vision's normalized boxes by the original upright size.
    let maxDimension = arguments["maxDimension"] as? Int ?? 2200
    let workingImage: CGImage
    if maxDimension > 0 && max(cgImage.width, cgImage.height) > maxDimension,
       let downscaled = downscaled(cgImage, toFit: maxDimension) {
      workingImage = downscaled
    } else {
      workingImage = cgImage
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel =
      (arguments["recognitionLevel"] as? String) == "fast" ? .fast : .accurate

    if let languages = arguments["languages"] as? [String], !languages.isEmpty {
      let supported = (try? request.supportedRecognitionLanguages()) ?? []
      let filtered = languages.filter { supported.contains($0) }
      if !filtered.isEmpty {
        request.recognitionLanguages = filtered
      }
    }
    if #available(iOS 16.0, macOS 13.0, *) {
      request.automaticallyDetectsLanguage = arguments["automaticallyDetectsLanguage"] as? Bool ?? false
    }

    let handler = VNImageRequestHandler(cgImage: workingImage, orientation: orientation, options: [:])
    try handler.perform([request])
    // Read through the base type: VNRequest.results is [Any]?, so this cast is
    // a genuine downcast on every SDK revision (no-op warning is avoided).
    let observations = (request as VNRequest).results as? [VNRecognizedTextObservation] ?? []

    let lines: [[String: Any]] = observations.compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return nil }
      let box = observation.boundingBox
      return [
        "text": text,
        "confidence": Double(candidate.confidence),
        "left": Double(box.minX * upright.width),
        "top": Double((1 - box.maxY) * upright.height),
        "width": Double(box.width * upright.width),
        "height": Double(box.height * upright.height),
      ]
    }
    // Comic reading order: top-to-bottom, then left-to-right.
    .sorted {
      let top0 = $0["top"] as? Double ?? 0
      let top1 = $1["top"] as? Double ?? 0
      if abs(top0 - top1) > 1 { return top0 < top1 }
      return ($0["left"] as? Double ?? 0) < ($1["left"] as? Double ?? 0)
    }

    return [
      "width": Double(upright.width),
      "height": Double(upright.height),
      "orientation": orientation.rawValue,
      "lines": lines,
    ]
  }

  private static func uprightSize(for size: CGSize,
                                  orientation: CGImagePropertyOrientation) -> CGSize {
    switch orientation {
    case .left, .leftMirrored, .right, .rightMirrored:
      return CGSize(width: size.height, height: size.width)
    default:
      return size
    }
  }

  private static func downscaled(_ image: CGImage, toFit maxDimension: Int) -> CGImage? {
    let scale = min(1.0, CGFloat(maxDimension) / CGFloat(max(image.width, image.height)))
    let width = max(1, Int(CGFloat(image.width) * scale))
    let height = max(1, Int(CGFloat(image.height) * scale))
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      return image
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage() ?? image
  }

  // MARK: - Apple on-device translation

  /// Error codes produced by [translate]:
  /// 10 = empty text, 11 = TRANSLATION_UNAVAILABLE (OS too old or pair unsupported),
  /// 12 = translation failed, 13 = TRANSLATION_NOT_INSTALLED (language pack missing).
  ///
  /// Accepts `lines: [String]` and returns `["lines": [String]]` with the SAME
  /// count so the read-page overlay keeps a 1:1 mapping between source blocks
  /// and translated lines. Translating the whole page as one blob would merge
  /// or drop lines, which both misaligns the overlay and loses dialogue.
  static func translate(arguments: [String: Any]) async throws -> [String: Any] {
    let lines: [String]
    if let rawLines = arguments["lines"] as? [String], !rawLines.isEmpty {
      lines = rawLines
    } else if let text = arguments["text"] as? String, !text.isEmpty {
      lines = [text]
    } else {
      throw NSError(domain: "LiveTextOCR", code: 10,
                    userInfo: [NSLocalizedDescriptionKey: "Empty text"])
    }
    let targetCode = (arguments["target"] as? String) ?? "zh-Hans"
    let sourceCode = arguments["source"] as? String
    let joined = lines.joined(separator: "\n")

    // The Translation framework is only constructible on iOS 26 / macOS 26+
    // with the current SDK. On older systems fall through to UNAVAILABLE so the
    // caller can degrade (e.g. fall back to the configured third-party API).
    if #available(iOS 26.0, macOS 26.0, *) {
      let target = Locale.Language(identifier: targetCode)
      let source: Locale.Language
      if let sourceCode, !sourceCode.isEmpty {
        source = Locale.Language(identifier: sourceCode)
      } else {
        source = Locale.Language(identifier: detectSourceLanguage(joined))
      }
      // Prefer the high-fidelity model for quality (casual/manga dialogue is
      // where the default/low-latency strategy degrades most).
      let session: TranslationSession
      if #available(iOS 26.4, macOS 26.4, *) {
        session = TranslationSession(
          installedSource: source, target: target, preferredStrategy: .highFidelity)
      } else {
        session = TranslationSession(installedSource: source, target: target)
      }
      // The pair must be installed for on-device translation. `supported` but
      // not `installed` means the user has to install the language pack first
      // (iPhone: Settings > Translate > Downloaded Languages; macOS: System
      // Settings > General > Language & Region > Translation Languages);
      // apps cannot always trigger that download themselves.
      let availability = LanguageAvailability()
      let status = await availability.status(from: source, to: target)
      switch status {
      case .unsupported:
        throw NSError(domain: "LiveTextOCR", code: 11,
                      userInfo: [NSLocalizedDescriptionKey: "TRANSLATION_UNAVAILABLE"])
      case .supported:
        // Try to download; report NOT_INSTALLED if that is not permitted.
        do {
          try await session.prepareTranslation()
        } catch {
          NSLog("LiveTextOCR prepareTranslation failed: \(error)")
          throw NSError(domain: "LiveTextOCR", code: 13,
                        userInfo: [NSLocalizedDescriptionKey: "TRANSLATION_NOT_INSTALLED",
                                   NSDebugDescriptionErrorKey: (error as NSError).localizedDescription])
        }
      case .installed:
        break
      @unknown default:
        break
      }
      do {
        let translated = try await translateLines(lines, session: session)
        return ["lines": translated]
      } catch {
        let message = (error as NSError).localizedDescription
        NSLog("LiveTextOCR translate failed: \(error)")
        throw NSError(domain: "LiveTextOCR", code: 12,
                      userInfo: [NSLocalizedDescriptionKey: "TRANSLATION_FAILED",
                                 NSDebugDescriptionErrorKey: message])
      }
    }
    throw NSError(domain: "LiveTextOCR", code: 11,
                  userInfo: [NSLocalizedDescriptionKey: "TRANSLATION_UNAVAILABLE"])
  }

  /// Translates lines preserving the count. Uses the batched API so each line
  /// keeps its own translation; falls back to per-line calls (keeping the
  /// source text for any line that fails) so the overlay never loses a bubble.
  @available(iOS 18.0, macOS 15.0, *)
  private static func translateLines(_ lines: [String],
                                     session: TranslationSession) async throws -> [String] {
    // Translate only non-empty lines; empty slots are passed through as-is so
    // the returned array always has the same length as `lines`.
    let indices = lines.indices.filter {
      !lines[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    let nonEmpty = indices.map { lines[$0] }
    guard !nonEmpty.isEmpty else { return lines }

    var translated = lines
    do {
      let responses = try await session.translations(
        from: nonEmpty.map { TranslationSession.Request(sourceText: $0) })
      guard responses.count == nonEmpty.count else { throw NSError(domain: "LiveTextOCR", code: 12, userInfo: [:]) }
      for (offset, index) in indices.enumerated() {
        let value = responses[offset].targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        translated[index] = value.isEmpty ? lines[index] : value
      }
      return translated
    } catch {
      // Batch failed (e.g. one line is untranslatable): translate one by one,
      // falling back to the source line so every bubble keeps its slot.
      for index in indices {
        let source = lines[index]
        do {
          let response = try await session.translate(source)
          let value = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
          translated[index] = value.isEmpty ? source : value
        } catch {
          translated[index] = source
        }
      }
      return translated
    }
  }

  private static func detectSourceLanguage(_ text: String) -> String {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let language = recognizer.dominantLanguage?.rawValue else { return "en" }
    return language
  }
}
