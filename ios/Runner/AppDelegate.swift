import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

// All pages use the same display-based status axis: native on the cover,
// horizontal on the inner display. Reader visibility follows immersive mode.
class JHFlutterViewController: FlutterViewController {
  private var usesHorizontalBars = false
  private var readerActive = false
  private var readerImmersive = false
  private var geometryChannel: FlutterMethodChannel?
  private var lastGeometry: NSDictionary?
  private var geometryPending = false

  override func viewDidLoad() {
    super.viewDidLoad()
    geometryChannel = FlutterMethodChannel(name: "top.jtmonster.jhentai/window_geometry", binaryMessenger: binaryMessenger)
    geometryChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getGeometry":
        result(self?.windowGeometry())
      case "setReaderState":
        guard let self else { result(nil); return }
        guard let state = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_reader_state", message: "Expected reader state", details: nil))
          return
        }
        self.readerActive = state["active"] as? Bool ?? false
        self.readerImmersive = self.readerActive && (state["immersive"] as? Bool ?? false)
        self.updateBarConfiguration(for: self.view.bounds.size)
        self.setNeedsStatusBarAppearanceUpdate()
        self.scheduleGeometryUpdate()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    updateBarConfiguration(for: view.bounds.size)
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateBarConfiguration(for: size)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // Covers display changes while backgrounded and resizes without rotation.
    updateBarConfiguration(for: view.bounds.size)
    scheduleGeometryUpdate()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    scheduleGeometryUpdate()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    scheduleGeometryUpdate()
  }

  private func scheduleGeometryUpdate() {
    guard !geometryPending else { return }
    geometryPending = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.geometryPending = false
      guard let packet = self.windowGeometry() else { return }
      let dictionary = packet as NSDictionary
      guard self.lastGeometry?.isEqual(to: packet) != true else { return }
      self.lastGeometry = dictionary
      self.geometryChannel?.invokeMethod("geometryChanged", arguments: packet)
    }
  }

  private func windowGeometry() -> [String: Any]? {
    guard isViewLoaded, let window = view.window, let scene = window.windowScene else { return nil }
    let manager = scene.statusBarManager
    let status = view.convert(manager?.statusBarFrame ?? .zero, from: scene.coordinateSpace)
    let safe = view.safeAreaInsets
    let frame = view.convert(view.bounds, to: window)
    return [
      "width": view.bounds.width, "height": view.bounds.height,
      "statusBar": ["x": status.minX, "y": status.minY, "width": status.width, "height": status.height],
      "safeArea": ["top": safe.top, "right": safe.right, "bottom": safe.bottom, "left": safe.left],
      "horizontalBars": usesHorizontalBars, "statusBarHidden": manager?.isStatusBarHidden ?? true,
      "readerActive": readerActive, "readerImmersive": readerImmersive,
      "viewFrameInWindow": ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height],
      "windowWidth": window.bounds.width, "windowHeight": window.bounds.height,
      "displayScale": traitCollection.displayScale,
    ]
  }

  private func updateBarConfiguration(for size: CGSize) {
    // Reading changes visibility only. Keeping this independent of readerActive
    // avoids a second safe-area layout when returning to the gallery.
    // The shortest edge also keeps the cover native when held sideways.
    let horizontal = min(size.width, size.height) >= 600
    guard horizontal != usesHorizontalBars else { return }
    usesHorizontalBars = horizontal
    if #available(iOS 27.1, *) {
      setNeedsUpdateOfVerticalBarConfiguration()
    }
  }

  override var prefersStatusBarHidden: Bool {
    readerImmersive || super.prefersStatusBarHidden
  }

  @available(iOS 27.1, *)
  override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    usesHorizontalBars ? .disabled : .automatic
  }
}
