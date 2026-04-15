import ArgumentParser
import Foundation
import VOICEVOX

@main
struct VoicevoxClientCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "voicevox-client",
    abstract: "VOICEVOX text-to-speech CLI tool",
    subcommands: [Synthesize.self, Query.self, SynthesizeFromQuery.self, Speakers.self, Setup.self],
    defaultSubcommand: Synthesize.self
  )

  static func main() async {
    // Suppress VOICEVOX Core's Rust log output unless the user explicitly sets RUST_LOG
    if ProcessInfo.processInfo.environment["RUST_LOG"] == nil {
      setenv("RUST_LOG", "error", 0)
    }
    await self.main(nil)
  }
}

enum DefaultPaths {
  static var home: String {
    ProcessInfo.processInfo.environment["VOICEVOX_CLIENT_HOME"]
      ?? FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".voicevox-client").path()
  }

  static var resourcesDir: String {
    URL(filePath: home).appending(path: "resources").path()
  }
}

struct CommonOptions: ParsableArguments {
  @Option(name: .long, help: "Path to the OpenJTalk dictionary directory (default: ~/.voicevox-client/resources/open_jtalk_dic_utf_8)")
  var dictPath: String?

  @Option(name: .long, help: "Path to the OnnxRuntime dylib directory (default: ~/.voicevox-client/resources)")
  var onnxruntimePath: String?

  @Option(name: .long, help: "Path to the voice model file (.vvm) (default: ~/.voicevox-client/resources/vvms/0.vvm)")
  var modelPath: String?

  @Option(name: .long, help: "Voice model name (e.g., 0, 1, s0) — resolved to <resources>/vvms/<name>.vvm")
  var modelName: String?

  @Option(name: .long, help: "Number of CPU threads (0 = auto)")
  var cpuNumThreads: UInt16 = 0
}

extension CommonOptions {
  func makeConfiguration() -> VOICEVOXConfiguration {
    let base = DefaultPaths.resourcesDir
    let resolvedDictPath = dictPath ?? "\(base)/open_jtalk_dic_utf_8"
    let resolvedOnnxruntimePath = onnxruntimePath ?? base
    return VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(filePath: resolvedDictPath),
      onnxruntimeDirectoryURL: URL(filePath: resolvedOnnxruntimePath),
      cpuNumThreads: cpuNumThreads
    )
  }

  var resolvedModelPath: String {
    let base = DefaultPaths.resourcesDir
    if let modelPath {
      return modelPath
    } else if let modelName {
      return "\(base)/vvms/\(modelName).vvm"
    } else {
      return "\(base)/vvms/0.vvm"
    }
  }

  func createSynthesizer() async throws -> Synthesizer {
    let configuration = makeConfiguration()
    let synthesizer = try await Synthesizer(configuration: configuration)
    try await synthesizer.loadVoiceModel(from: URL(filePath: resolvedModelPath))
    return synthesizer
  }
}

struct Synthesize: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Synthesize speech from text"
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .shortAndLong, help: "Text to synthesize")
  var text: String

  @Flag(name: .long, help: "Treat input text as AquesTalk-like kana notation (e.g., \"コンニチワ'\")")
  var kana: Bool = false

  @Option(name: .shortAndLong, help: "Voice style ID")
  var styleId: UInt32 = 0

  @Option(name: .shortAndLong, help: "Output WAV file path")
  var output: String = "output.wav"

  @Option(name: .long, help: "Speed scale (1.0 = normal)")
  var speed: Float?

  @Option(name: .long, help: "Pitch scale (1.0 = normal)")
  var pitch: Float?

  @Option(name: .long, help: "Intonation scale (1.0 = normal)")
  var intonation: Float?

  @Option(name: .long, help: "Volume scale (1.0 = normal)")
  var volume: Float?

  func run() async throws {
    let synthesizer = try await common.createSynthesizer()

    if speed != nil || pitch != nil || intonation != nil || volume != nil {
      var audioQuery = kana
        ? try await synthesizer.makeAudioQuery(kana: text, styleId: styleId)
        : try await synthesizer.makeAudioQuery(text: text, styleId: styleId)
      if let speed { audioQuery.speedScale = speed }
      if let pitch { audioQuery.pitchScale = pitch }
      if let intonation { audioQuery.intonationScale = intonation }
      if let volume { audioQuery.volumeScale = volume }

      let wavData = try await synthesizer.synthesize(audioQuery: audioQuery, styleId: styleId)
      try wavData.write(to: URL(filePath: output))
    } else if kana {
      let wavData = try await synthesizer.synthesize(kana: text, styleId: styleId)
      try wavData.write(to: URL(filePath: output))
    } else {
      let wavData = try await synthesizer.synthesize(text: text, styleId: styleId)
      try wavData.write(to: URL(filePath: output))
    }

    print("Saved to \(output)")
  }
}

struct Query: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Generate an audio query as JSON"
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .shortAndLong, help: "Text to analyze")
  var text: String

  @Flag(name: .long, help: "Treat input text as AquesTalk-like kana notation")
  var kana: Bool = false

  @Option(name: .shortAndLong, help: "Voice style ID")
  var styleId: UInt32 = 0

  @Option(name: .shortAndLong, help: "Output JSON file path (default: stdout)")
  var output: String?

  func run() async throws {
    let synthesizer = try await common.createSynthesizer()
    let audioQuery = kana
      ? try await synthesizer.makeAudioQuery(kana: text, styleId: styleId)
      : try await synthesizer.makeAudioQuery(text: text, styleId: styleId)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(audioQuery)

    if let output {
      try jsonData.write(to: URL(filePath: output))
      FileHandle.standardError.write(Data("Saved to \(output)\n".utf8))
    } else {
      FileHandle.standardOutput.write(jsonData)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }
  }
}

struct SynthesizeFromQuery: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "synthesize-from-query",
    abstract: "Synthesize speech from an audio query JSON"
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .shortAndLong, help: "Input audio query JSON file path (use - for stdin)")
  var input: String

  @Option(name: .shortAndLong, help: "Voice style ID")
  var styleId: UInt32 = 0

  @Option(name: .shortAndLong, help: "Output WAV file path")
  var output: String = "output.wav"

  func run() async throws {
    let jsonData: Data
    if input == "-" {
      jsonData = FileHandle.standardInput.readDataToEndOfFile()
    } else {
      jsonData = try Data(contentsOf: URL(filePath: input))
    }

    let audioQuery = try JSONDecoder().decode(AudioQuery.self, from: jsonData)
    let synthesizer = try await common.createSynthesizer()
    let wavData = try await synthesizer.synthesize(audioQuery: audioQuery, styleId: styleId)
    try wavData.write(to: URL(filePath: output))
    print("Saved to \(output)")
  }
}

struct Speakers: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List available speakers and styles"
  )

  @OptionGroup var common: CommonOptions

  @Flag(name: .long, help: "List speakers from all .vvm files in the vvms directory")
  var all: Bool = false

  func run() async throws {
    if all {
      try listAllSpeakers()
    } else {
      try await listLoadedSpeakers()
    }
  }

  private func listLoadedSpeakers() async throws {
    let modelPath = common.resolvedModelPath
    print("Model: \(modelPath)")
    print("")

    let synthesizer = try await common.createSynthesizer()
    let speakers = try await synthesizer.getSpeakers()
    printSpeakers(speakers)
  }

  private func listAllSpeakers() throws {
    let vvmsDir = URL(filePath: DefaultPaths.resourcesDir).appending(path: "vvms")
    let fm = FileManager.default

    guard let entries = try? fm.contentsOfDirectory(at: vvmsDir, includingPropertiesForKeys: nil) else {
      print("No vvms directory found at \(vvmsDir.path())")
      return
    }

    let vvmFiles = entries
      .filter { $0.pathExtension == "vvm" }
      .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

    if vvmFiles.isEmpty {
      print("No .vvm files found in \(vvmsDir.path())")
      return
    }

    for vvmFile in vvmFiles {
      let name = vvmFile.deletingPathExtension().lastPathComponent
      do {
        let speakers = try Synthesizer.speakers(from: vvmFile)
        print("[\(name)] \(vvmFile.path())")
        printSpeakers(speakers)
        print("")
      } catch {
        print("[\(name)] Failed to read: \(error.localizedDescription)")
      }
    }
  }

  private func printSpeakers(_ speakers: [Speaker]) {
    for speaker in speakers {
      print("  \(speaker.name) (UUID: \(speaker.speakerUUID))")
      for style in speaker.styles {
        print("    [\(style.id)] \(style.name) (type: \(style.type))")
      }
    }
  }
}
