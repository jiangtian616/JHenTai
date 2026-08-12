import Cocoa
import FlutterMacOS
import macos_window_utils
import window_manager

class MainFlutterWindow: NSWindow {
  private var liveTextChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    titleVisibility = .visible
    titlebarAppearsTransparent = false

    // Before the first Flutter frame the window shows its own background.
    // Follow the system appearance so startup is black in dark mode instead
    // of a white flash; the dynamic color re-evaluates when appearance changes.
    backgroundColor = NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return isDark ? .black : .white
    }

    let windowFrame = self.frame
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController
    self.setFrame(windowFrame, display: true)

    /* Initialize the macos_window_utils plugin */
    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    let channel = FlutterMethodChannel(
      name: LiveTextOCR.channelName,
      binaryMessenger: macOSWindowUtilsViewController.flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "recognizeText":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let response = try LiveTextOCR.run(arguments: args)
            DispatchQueue.main.async { result(response) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "OCR_FAILED",
                                  message: error.localizedDescription,
                                  details: nil))
            }
          }
        }
      case "translateText":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        Task {
          do {
            let response = try await LiveTextOCR.translate(arguments: args)
            await MainActor.run { result(response) }
          } catch {
            let nsError = error as NSError
            let code: String
            if nsError.domain == "LiveTextOCR" && nsError.code == 11 {
              code = "TRANSLATION_UNAVAILABLE"
            } else if nsError.domain == "LiveTextOCR" && nsError.code == 13 {
              code = "TRANSLATION_NOT_INSTALLED"
            } else {
              code = "TRANSLATION_FAILED"
            }
            await MainActor.run {
              result(FlutterError(code: code,
                                  message: nsError.localizedDescription,
                                  details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    liveTextChannel = channel

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
