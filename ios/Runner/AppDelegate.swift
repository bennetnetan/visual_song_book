import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let converterChannel = "visual_song_book/vsb_converter"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VsbAccessConverter") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: Self.converterChannel,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "convertAccessFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let inputPath = arguments["path"] as? String,
            !inputPath.isEmpty else {
        result(FlutterError(code: "missing_path", message: "No Access file path was provided.", details: nil))
        return
      }
      Task {
        do {
          let outputPath = try await Self.convertAccessFile(inputPath)
          result(outputPath)
        } catch {
          result(FlutterError(code: "conversion_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func convertAccessFile(_ inputPath: String) async throws -> String {
    guard let bundledProject = Bundle.main.resourceURL?.appendingPathComponent("NodeProject", isDirectory: true) else {
      throw NSError(domain: "VsbConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled songbook converter is missing."])
    }
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let project = support.appendingPathComponent("VisualSongBookNodeProject", isDirectory: true)
    if !FileManager.default.fileExists(atPath: project.path) {
      try FileManager.default.copyItem(at: bundledProject, to: project)
    }
    VsbNodeRunner.start(projectPath: project.path)

    let baseURL = URL(string: "http://localhost:39873")!
    var ready = false
    for _ in 0..<60 {
      let healthRequest = URLRequest(url: baseURL.appendingPathComponent("health"))
      if let response = try? await requestData(for: healthRequest),
         (response.1 as? HTTPURLResponse)?.statusCode == 200 {
        ready = true
        break
      }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    guard ready else {
      throw NSError(domain: "VsbConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "The bundled Access converter did not start."])
    }

    let output = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("vsbook")
    var request = URLRequest(url: baseURL.appendingPathComponent("convert"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["inputPath": inputPath, "outputPath": output.path])
    let (data, response) = try await requestData(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let message = (try? JSONSerialization.jsonObject(with: data) as? [String: String])?["error"]
        ?? "The Access songbook could not be converted."
      throw NSError(domain: "VsbConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: message])
    }
    return output.path
  }

  private static func requestData(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, URLResponse), Error>) in
      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let data, let response {
          continuation.resume(returning: (data, response))
        } else {
          continuation.resume(throwing: NSError(domain: "VsbConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "No response from the bundled converter."]))
        }
      }.resume()
    }
  }
}
