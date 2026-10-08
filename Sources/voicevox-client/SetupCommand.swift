import ArgumentParser
import Foundation
import VOICEVOX

struct Setup: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Download and set up VOICEVOX resources"
  )

  @Option(
    name: .shortAndLong,
    help: "Output directory for resources (default: $VOICEVOX_CLIENT_HOME/resources or ~/.voicevox-client/resources)"
  )
  var output: String?

  @Option(name: .long, help: "VOICEVOX Core version")
  var version: String = "0.17.0"

  private static let onnxruntimeVersion = "1.17.3"

  func run() async throws {
    let fm = FileManager.default
    let outputPath = output ?? DefaultPaths.resourcesDir
    print("Using resources directory: \(outputPath)")
    let outputURL = URL(filePath: outputPath)
    try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let tempDir = fm.temporaryDirectory
      .appending(path: "voicevox-setup-\(ProcessInfo.processInfo.globallyUniqueString)")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    // 1. Download and run the VOICEVOX downloader for models, dict, onnxruntime
    let resourcesDir = tempDir.appending(path: "resources")
    try await downloadComponents(to: resourcesDir, workingDirectory: tempDir)

    // 2. Copy resources to output directory
    print("Setting up resources...")

    let vvmsSource = resourcesDir.appending(path: "models/vvms")
    let vvmsDest = outputURL.appending(path: "vvms")
    try replaceItem(at: vvmsDest, with: vvmsSource)

    let dictSource = resourcesDir.appending(path: "dict/open_jtalk_dic_utf_8-1.11")
    let dictDest = outputURL.appending(path: "open_jtalk_dic_utf_8")
    try replaceItem(at: dictDest, with: dictSource)

    let onnxFileName = "libvoicevox_onnxruntime.\(Self.onnxruntimeVersion).dylib"
    let onnxSource = resourcesDir.appending(path: "onnxruntime/lib/\(onnxFileName)")
    let onnxDest = outputURL.appending(path: onnxFileName)
    try replaceItem(at: onnxDest, with: onnxSource)

    // 3. Download and install VOICEVOX Core library
    try await installCoreLibrary(to: outputURL, workingDirectory: tempDir)

    print("Setup complete! Resources saved to: \(outputPath)")
    print("")
    print("Usage:")
    print("  voicevox-client --text \"こんにちは\"")
  }

  private func downloadComponents(to resourcesDir: URL, workingDirectory: URL) async throws {
    let downloaderURL = workingDirectory.appending(path: "download")

    print("Downloading VOICEVOX downloader...")
    try await download(
      from: "https://github.com/VOICEVOX/voicevox_core/releases/download/\(version)/download-osx-\(currentArch())",
      to: downloaderURL
    )
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloaderURL.fileSystemPath)
    removeQuarantine(downloaderURL)

    let componentArguments: [(component: String, arguments: [String])] = [
      ("models", []),
      ("dict", []),
      ("onnxruntime", ["--onnxruntime-version", Self.onnxruntimeVersion]),
    ]
    for (component, arguments) in componentArguments {
      print("Downloading \(component)...")
      try runDownloader(downloaderURL, output: resourcesDir, only: component, arguments: arguments)
    }
  }

  private func installCoreLibrary(to outputURL: URL, workingDirectory: URL) async throws {
    let archiveName = "voicevox_core-osx-\(currentArch())-\(version)"
    let coreZipURL = workingDirectory.appending(path: "voicevox_core.zip")
    print("Downloading VOICEVOX Core library...")
    try await download(
      from: "https://github.com/VOICEVOX/voicevox_core/releases/download/\(version)/\(archiveName).zip",
      to: coreZipURL
    )
    try unzip(coreZipURL, to: workingDirectory)

    let coreDylib = workingDirectory.appending(path: "\(archiveName)/lib/libvoicevox_core.dylib")
    let coreDest = outputURL.appending(path: "libvoicevox_core.dylib")
    try replaceItem(at: coreDest, with: coreDylib)

    try runProcess("/usr/bin/install_name_tool", arguments: [
      "-id", "@rpath/libvoicevox_core.dylib", coreDest.fileSystemPath,
    ])
    // Changing the install name invalidates the upstream Developer ID signature, and macOS kills
    // processes that load a dylib with an invalid signature.
    try runProcess("/usr/bin/codesign", arguments: ["--force", "--sign", "-", coreDest.fileSystemPath])
  }

  // MARK: - Helpers

  private func currentArch() -> String {
    #if arch(arm64)
    "arm64"
    #else
    "x64"
    #endif
  }

  private func download(from urlString: String, to destination: URL) async throws {
    guard let url = URL(string: urlString) else {
      throw SetupError.invalidURL(urlString)
    }
    let (tempURL, response) = try await URLSession.shared.download(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw SetupError.downloadFailed(urlString)
    }
    let fm = FileManager.default
    if fm.fileExists(atPath: destination.fileSystemPath) {
      try fm.removeItem(at: destination)
    }
    try fm.moveItem(at: tempURL, to: destination)
  }

  private func removeQuarantine(_ url: URL) {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/xattr")
    process.arguments = ["-d", "com.apple.quarantine", url.fileSystemPath]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
  }

  private func runDownloader(_ downloaderURL: URL, output: URL, only: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = downloaderURL
    process.arguments = ["--output", output.fileSystemPath, "--only", only] + arguments
    process.environment = (ProcessInfo.processInfo.environment).merging(["PAGER": "/bin/cat"]) { _, new in new }

    let inputPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = FileHandle.nullDevice

    try process.run()
    inputPipe.fileHandleForWriting.write(Data("y\n".utf8))
    inputPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw SetupError.downloaderFailed(only, process.terminationStatus)
    }
  }

  private func unzip(_ zipURL: URL, to directory: URL) throws {
    try runProcess("/usr/bin/unzip", arguments: ["-q", zipURL.fileSystemPath, "-d", directory.fileSystemPath])
  }

  private func runProcess(_ path: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(filePath: path)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw SetupError.processFailed(path, process.terminationStatus)
    }
  }

  private func replaceItem(at destination: URL, with source: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: destination.fileSystemPath) {
      try fm.removeItem(at: destination)
    }
    try fm.copyItem(at: source, to: destination)
  }
}

enum SetupError: LocalizedError {
  case invalidURL(String)
  case downloadFailed(String)
  case downloaderFailed(String, Int32)
  case processFailed(String, Int32)

  var errorDescription: String? {
    switch self {
    case let .invalidURL(url):
      "Invalid URL: \(url)"
    case let .downloadFailed(url):
      "Failed to download: \(url)"
    case let .downloaderFailed(component, code):
      "VOICEVOX downloader failed for '\(component)' (exit code: \(code))"
    case let .processFailed(path, code):
      "\(path) failed (exit code: \(code))"
    }
  }
}
