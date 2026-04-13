import ArgumentParser
import Foundation
import VOICEVOX

@main
struct VoicevoxClientCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "voicevox-client",
    abstract: "VOICEVOX text-to-speech CLI tool",
    subcommands: [Synthesize.self, Speakers.self, Setup.self],
    defaultSubcommand: Synthesize.self
  )
}

enum DefaultPaths {
  static var resourcesDir: String {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".voicevox-client/resources").path()
  }
}

struct CommonOptions: ParsableArguments {
  @Option(name: .long, help: "Path to the OpenJTalk dictionary directory (default: ~/.voicevox-client/resources/open_jtalk_dic_utf_8)")
  var dictPath: String?

  @Option(name: .long, help: "Path to the OnnxRuntime dylib directory (default: ~/.voicevox-client/resources)")
  var onnxruntimePath: String?

  @Option(name: .long, help: "Path to the voice model file (.vvm) (default: ~/.voicevox-client/resources/vvms/0.vvm)")
  var modelPath: String?

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

  func createSynthesizer() async throws -> Synthesizer {
    let base = DefaultPaths.resourcesDir
    let resolvedModelPath = modelPath ?? "\(base)/vvms/0.vvm"
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

struct Speakers: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List available speakers and styles"
  )

  @OptionGroup var common: CommonOptions

  func run() async throws {
    let synthesizer = try await common.createSynthesizer()
    let speakers = try await synthesizer.getSpeakers()

    for speaker in speakers {
      print("\(speaker.name) (UUID: \(speaker.speakerUUID))")
      for style in speaker.styles {
        print("  [\(style.id)] \(style.name) (type: \(style.type))")
      }
    }
  }
}
