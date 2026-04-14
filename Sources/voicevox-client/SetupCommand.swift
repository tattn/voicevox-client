import ArgumentParser
import Foundation

struct Setup: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Download and set up VOICEVOX resources"
  )

  @Option(name: .shortAndLong, help: "Output directory for resources (default: $VOICEVOX_CLIENT_HOME/resources or ~/.voicevox-client/resources)")
  var output: String?

  @Option(name: .long, help: "VOICEVOX Core version")
  var version: String = "0.16.3"

  func run() async throws {
    let fm = FileManager.default
    let outputPath = output ?? DefaultPaths.resourcesDir
    print("Using resources directory: \(outputPath)")
    let outputURL = URL(filePath: outputPath)
    try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let tempDir = fm.temporaryDirectory.appending(path: "voicevox-setup-\(ProcessInfo.processInfo.globallyUniqueString)")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    // 1. Download and run the VOICEVOX downloader for models, dict, onnxruntime
    let downloaderURL = tempDir.appending(path: "download")
    let resourcesDir = tempDir.appending(path: "resources")

    print("Downloading VOICEVOX downloader...")
    let arch = currentArch()
    try await download(
      from: "https://github.com/VOICEVOX/voicevox_core/releases/download/\(version)/download-osx-\(arch)",
      to: downloaderURL
    )
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloaderURL.path())
    removeQuarantine(downloaderURL)

    for component in ["models", "dict", "onnxruntime"] {
      print("Downloading \(component)...")
      try runDownloader(downloaderURL, output: resourcesDir, only: component)
    }

    // 2. Download VOICEVOX Core library
    let coreZipURL = tempDir.appending(path: "voicevox_core.zip")
    print("Downloading VOICEVOX Core library...")
    try await download(
      from: "https://github.com/VOICEVOX/voicevox_core/releases/download/\(version)/voicevox_core-osx-\(arch)-\(version).zip",
      to: coreZipURL
    )
    try unzip(coreZipURL, to: tempDir)

    // 3. Copy resources to output directory
    print("Setting up resources...")

    let vvmsSource = resourcesDir.appending(path: "models/vvms")
    let vvmsDest = outputURL.appending(path: "vvms")
    try replaceItem(at: vvmsDest, with: vvmsSource)

    let dictSource = resourcesDir.appending(path: "dict/open_jtalk_dic_utf_8-1.11")
    let dictDest = outputURL.appending(path: "open_jtalk_dic_utf_8")
    try replaceItem(at: dictDest, with: dictSource)

    let coreExtracted = tempDir.appending(path: "voicevox_core-osx-\(arch)-\(version)")
    let coreDylib = coreExtracted.appending(path: "lib/libvoicevox_core.dylib")
    let coreDest = outputURL.appending(path: "libvoicevox_core.dylib")
    try replaceItem(at: coreDest, with: coreDylib)

    let onnxSource = resourcesDir.appending(path: "onnxruntime/lib/libvoicevox_onnxruntime.1.17.3.dylib")
    let onnxDest = outputURL.appending(path: "libvoicevox_onnxruntime.1.17.3.dylib")
    try replaceItem(at: onnxDest, with: onnxSource)

    // 4. Fix dylib install names
    try runProcess("/usr/bin/install_name_tool", arguments: [
      "-id", "@rpath/libvoicevox_core.dylib", coreDest.path(),
    ])

    print("Setup complete! Resources saved to: \(outputPath)")
    print("")
    print("Usage:")
    print("  voicevox-client --text \"こんにちは\"")
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
    if fm.fileExists(atPath: destination.path()) {
      try fm.removeItem(at: destination)
    }
    try fm.moveItem(at: tempURL, to: destination)
  }

  private func removeQuarantine(_ url: URL) {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/xattr")
    process.arguments = ["-d", "com.apple.quarantine", url.path()]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
  }

  private func runDownloader(_ downloaderURL: URL, output: URL, only: String) throws {
    let process = Process()
    process.executableURL = downloaderURL
    process.arguments = ["--output", output.path(), "--only", only]
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
    try runProcess("/usr/bin/unzip", arguments: ["-q", zipURL.path(), "-d", directory.path()])
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
    if fm.fileExists(atPath: destination.path()) {
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
    case .invalidURL(let url):
      "Invalid URL: \(url)"
    case .downloadFailed(let url):
      "Failed to download: \(url)"
    case .downloaderFailed(let component, let code):
      "VOICEVOX downloader failed for '\(component)' (exit code: \(code))"
    case .processFailed(let path, let code):
      "\(path) failed (exit code: \(code))"
    }
  }
}
