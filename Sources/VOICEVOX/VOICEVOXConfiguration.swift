import Foundation
import voicevox_core

/// Configuration settings for initializing the VOICEVOX engine.
///
/// This structure contains all the necessary parameters to configure the VOICEVOX
/// text-to-speech engine, including dictionary paths, acceleration settings,
/// and thread configuration.
public struct VOICEVOXConfiguration: Sendable {
  /// The URL to the OpenJTalk dictionary directory.
  ///
  /// This directory should contain the OpenJTalk morphological analysis
  /// dictionary files, typically named "open_jtalk_dic_utf_8-1.11" or similar.
  /// The dictionary is required for proper Japanese text processing.
  public let openJTalkDictionaryURL: URL

  /// The number of CPU threads to use for inference.
  ///
  /// When set to 0 (default), the engine automatically determines the
  /// optimal number of threads based on the system capabilities.
  /// For manual control, specify the desired thread count.
  public let cpuNumThreads: UInt16

  /// Creates a new VOICEVOX configuration.
  ///
  /// - Parameters:
  ///   - openJTalkDictionaryURL: The URL to the OpenJTalk dictionary directory.
  ///     This directory must exist and contain valid dictionary files.
  ///   - cpuNumThreads: The number of CPU threads to use. Defaults to 0 (auto).
  ///
  /// - Note: The configuration does not validate the dictionary path at creation time.
  ///   Path validation occurs during VOICEVOX initialization.
  public init(
    openJTalkDictionaryURL: URL,
    cpuNumThreads: UInt16 = 0
  ) {
    self.openJTalkDictionaryURL = openJTalkDictionaryURL
    self.cpuNumThreads = cpuNumThreads
  }
}

/// Options for text-to-speech synthesis.
///
/// This structure contains parameters that control the behavior of the
/// synthesis process, such as intonation and pronunciation adjustments.
public struct TTSOptions: Sendable {
  /// Whether to enable interrogative upspeak for question sentences.
  ///
  /// When enabled, sentences ending with question marks will have
  /// a rising intonation typical of interrogative speech. This can
  /// make synthesized questions sound more natural.
  public let enableInterrogativeUpspeak: Bool

  /// Creates new TTS options.
  ///
  /// - Parameter enableInterrogativeUpspeak: Whether to enable interrogative
  ///   upspeak for questions. Defaults to `true`.
  public init(enableInterrogativeUpspeak: Bool = true) {
    self.enableInterrogativeUpspeak = enableInterrogativeUpspeak
  }
}

// MARK: - TTSOptions Convenience

extension TTSOptions {
  /// Converts to VOICEVOX TTS options.
  func toVoicevoxTtsOptions() -> VoicevoxTtsOptions {
    var ttsOptions = voicevox_make_default_tts_options()
    ttsOptions.enable_interrogative_upspeak = enableInterrogativeUpspeak
    return ttsOptions
  }

  /// Standard TTS options with interrogative upspeak enabled.
  public static let standard = TTSOptions(enableInterrogativeUpspeak: true)

  /// TTS options with flat intonation (no interrogative upspeak).
  public static let flat = TTSOptions(enableInterrogativeUpspeak: false)
}
