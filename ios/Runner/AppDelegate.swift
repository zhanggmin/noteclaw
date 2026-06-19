import Flutter
import UIKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Show local notifications while the app is in the foreground.
  // flutter_local_notifications requires this delegate method to be implemented;
  // without it, iOS silently drops notifications when the app is active.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Let super (and therefore all Flutter plugins) initialise first, then
    // configure the audio session so there is no conflict with audio_service.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureAudioSession()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupUiAutomationChannel(engineBridge)
    setupSandboxChannel(engineBridge)
    setupICloudBackupChannel(engineBridge)
  }

  // MARK: - iCloud Backup

  private func setupICloudBackupChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "ICloudBackup")?.messenger() else { return }

    let channel = FlutterMethodChannel(
      name: "ai.flutterclaw/icloud_backup",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "saveBackup":
        guard let args = call.arguments as? [String: Any],
              let sourcePath = args["sourcePath"] as? String,
              let fileName = args["fileName"] as? String else {
          result(FlutterError(
            code: "BAD_ARGS",
            message: "sourcePath and fileName are required.",
            details: nil
          ))
          return
        }
        self.saveBackupToICloud(sourcePath: sourcePath, fileName: fileName, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func saveBackupToICloud(
    sourcePath: String,
    fileName: String,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fileManager = FileManager.default
      guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ICLOUD_UNAVAILABLE",
            message: "iCloud Drive is unavailable. Enable iCloud Drive and the app's iCloud permission.",
            details: nil
          ))
        }
        return
      }

      let backupsURL = containerURL
        .appendingPathComponent("Documents", isDirectory: true)
        .appendingPathComponent("Backups", isDirectory: true)
      let destinationURL = backupsURL.appendingPathComponent(fileName)
      let sourceURL = URL(fileURLWithPath: sourcePath)

      do {
        try fileManager.createDirectory(
          at: backupsURL,
          withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
          try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        DispatchQueue.main.async {
          result(destinationURL.path)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ICLOUD_SAVE_FAILED",
            message: "Failed to save backup to iCloud Drive: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    }
  }

  // MARK: - UI Automation (iOS: screenshot only; gestures not supported)

  private func setupUiAutomationChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "UiAutomation")?.messenger() else { return }

    let channel = FlutterMethodChannel(
      name: "ai.flutterclaw/ui_automation",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ui_check_permission":
        result([
          "granted": false,
          "platform": "ios",
          "note": "iOS does not support cross-app UI automation. Only ui_screenshot is available.",
        ])

      case "ui_request_permission":
        result([
          "launched_settings": false,
          "note": "No accessibility permission is required on iOS. Cross-app gesture automation is not supported on iOS.",
        ])

      case "ui_screenshot":
        self?.handleScreenshot(result: result)

      default:
        result(FlutterError(
          code: "IOS_NOT_SUPPORTED",
          message: "'\(call.method)' requires Android Accessibility Service and is not available on iOS.",
          details: nil
        ))
      }
    }
  }

  private func handleScreenshot(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first else {
        result(FlutterError(code: "SCREENSHOT_FAILED", message: "No window available", details: nil))
        return
      }
      let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
      let image = renderer.image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
      }
      guard let pngData = image.pngData() else {
        result(FlutterError(code: "SCREENSHOT_FAILED", message: "PNG encoding failed", details: nil))
        return
      }
      result([
        "data": pngData.base64EncodedString(),
        "mimeType": "image/png",
        "note": "iOS screenshot shows FlutterClaw app surface only. Cross-app screenshots require Android.",
      ])
    }
  }

  // MARK: - Sandbox Shell (iOS: TinyEMU RISC-V + Alpine 3.21 via WAMR)

  private var sandboxHandler: WasmSandboxHandler?
  // Keep streamChannel alive — if it were a local var it would be deallocated
  // after setupSandboxChannel returns, deregistering the EventChannel handler.
  private var sandboxStreamChannel: FlutterEventChannel?

  private func setupSandboxChannel(_ engineBridge: FlutterImplicitEngineBridge) {
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "Sandbox")?.messenger() else {
      print("[AppDelegate] setupSandboxChannel: messenger unavailable, sandbox disabled")
      return
    }
    sandboxHandler = WasmSandboxHandler(messenger: messenger)
    sandboxStreamChannel = FlutterEventChannel(
      name: "ai.flutterclaw/sandbox_stream",
      binaryMessenger: messenger
    )
    sandboxStreamChannel!.setStreamHandler(sandboxHandler)
    print("[AppDelegate] sandbox EventChannel registered")
  }

  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()

      // Set category to playback with mixWithOthers option
      // This allows our app to play audio while other apps are also playing
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )

      // Activate the audio session
      try audioSession.setActive(true)

      print("✅ Audio session configured for background playback")
    } catch {
      print("⚠️ Failed to configure audio session: \(error)")
    }
  }
}
