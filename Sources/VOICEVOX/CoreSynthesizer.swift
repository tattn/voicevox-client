import Foundation
import voicevox_common

/// A Swift wrapper around the VOICEVOX synthesizer.
///
/// The synthesizer is responsible for converting text to speech using VOICEVOX's
/// neural network-based voice synthesis engine. It provides a high-level interface
/// for text analysis, audio query generation, and audio synthesis operations.
///
/// - Important: Voice models must be loaded before synthesis operations.
/// - Note: This class is not thread-safe. Use appropriate synchronization if accessing from multiple threads.
final class CoreSynthesizer {
  // MARK: - Properties
  /// The underlying C pointer to the synthesizer.
  let pointer: OpaquePointer

  /// The ONNX Runtime instance for neural network inference.
  let onnxruntime: OnnxRuntime

  /// The OpenJTalk instance used for text analysis.
  let openJTalk: OpenJTalk

  // MARK: - Initialization

  /// Creates a new synthesizer instance.
  ///
  /// - Parameters:
  ///   - onnxruntime: The ONNX Runtime instance for neural network inference.
  ///   - openJTalk: The OpenJTalk instance for text analysis.
  ///   - configuration: Configuration parameters for the synthesizer.
  /// - Throws: ``VOICEVOXError/synthesizerCreationFailed(details:)`` if initialization fails.
  init(
    onnxruntime: OnnxRuntime,
    openJTalk: OpenJTalk,
    configuration: VOICEVOXConfiguration
  ) throws(VOICEVOXError) {
    var initializeOptions = voicevox_make_default_initialize_options()
    initializeOptions.cpu_num_threads = configuration.cpuNumThreads

    var synthesizer: OpaquePointer?
    let resultCode = voicevox_synthesizer_new(onnxruntime.pointer, openJTalk.pointer, initializeOptions, &synthesizer)

    guard resultCode == 0, let synthesizer else {
      let details = "Failed to create synthesizer with threads: \(configuration.cpuNumThreads)"
      throw .synthesizerCreationFailed(details: details)
    }

    self.pointer = synthesizer
    self.onnxruntime = onnxruntime
    self.openJTalk = openJTalk
  }

  /// Cleans up the synthesizer resources.
  deinit {
    voicevox_synthesizer_delete(pointer)
  }

  // MARK: - Voice Model Management

  /// Loads a voice model into the synthesizer.
  ///
  /// - Parameter file: The voice model file to load.
  /// - Throws: ``VOICEVOXError/voiceModelLoadFailed(path:reason:)`` if loading fails.
  func loadVoiceModel(from file: VoiceModelFile) throws(VOICEVOXError) {
    let loadResultCode = voicevox_synthesizer_load_voice_model(pointer, file.pointer)

    guard loadResultCode == 0 else {
      throw .voiceModelLoadFailed(
        path: file.url.path(),
        reason: "Failed to load voice model into synthesizer (error code: \(loadResultCode))"
      )
    }
  }

  /// Unloads a voice model from the synthesizer.
  ///
  /// - Parameter modelID: The ID of the voice model to unload.
  /// - Throws: ``VOICEVOXError/synthesisFailed(text:styleId:reason:)`` if unloading fails.
  func unloadVoiceModel(modelID: VoiceModelID) throws(VOICEVOXError) {
    let unloadResultCode = modelID.withPointer { tuplePtr in
      voicevox_synthesizer_unload_voice_model(pointer, tuplePtr)
    }

    guard unloadResultCode == 0 else {
      throw .synthesisFailed(
        text: nil,
        styleId: nil,
        reason: "Failed to unload voice model (ID: \(modelID)) from synthesizer (error code: \(unloadResultCode))"
      )
    }
  }

  /// Checks whether a voice model is currently loaded.
  ///
  /// - Parameter modelID: The ID of the voice model to check.
  /// - Returns: `true` if the voice model is loaded, `false` otherwise.
  func isVoiceModelLoaded(modelID: VoiceModelID) -> Bool {
    modelID.withPointer { tuplePtr in
      voicevox_synthesizer_is_loaded_voice_model(pointer, tuplePtr)
    }
  }

  // MARK: - Text Analysis and Synthesis

  /// Analyzes text and generates accent phrases using OpenJTalk.
  ///
  /// This method performs morphological analysis on the input text to generate
  /// accent phrases that can be used for speech synthesis.
  ///
  /// - Parameter text: The text to analyze. Should be in Japanese for optimal results.
  /// - Returns: ``AccentPhrases`` containing the analyzed accent phrases with mora information.
  /// - Throws: ``VOICEVOXError`` if the text analysis fails.
  func analyze(text: String) throws(VOICEVOXError) -> AccentPhrases {
    try AccentPhrases(text: text, openJTalk: openJTalk)
  }

  /// Creates an audio query from text for the specified voice style.
  ///
  /// This method performs the complete text-to-audio-query pipeline:
  /// 1. Analyzes the text using OpenJTalk to generate accent phrases
  /// 2. Replaces mora data based on the specified voice style
  /// 3. Creates an audio query containing all synthesis parameters
  ///
  /// - Parameters:
  ///   - text: The text to process. Should be in Japanese for optimal results.
  ///   - styleId: The voice style identifier from a loaded voice model.
  /// - Returns: ``AudioQuery`` containing all parameters needed for synthesis.
  /// - Throws: ``VOICEVOXError`` if any step in the process fails.
  func makeAudioQuery(text: String, styleId: UInt32) throws(VOICEVOXError) -> AudioQuery {
    // Step 1: Analyze text to generate accent phrases
    let accentPhrases = try analyze(text: text)

    // Step 2: Replace mora data with style-specific information
    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: styleId,
      synthesizer: self,
      text: text
    )

    // Step 3: Create audio query with synthesis parameters
    return try updatedAccentPhrases.toAudioQuery(
      text: text,
      styleId: styleId
    )
  }

  /// Synthesizes audio from an audio query.
  ///
  /// This method converts an audio query containing synthesis parameters
  /// into actual audio data using the VOICEVOX synthesis engine.
  ///
  /// - Parameters:
  ///   - audioQuery: The audio query containing synthesis parameters.
  ///   - styleId: The voice style identifier that must match a loaded voice model.
  ///   - options: Additional synthesis options. Defaults to standard options.
  /// - Returns: Audio data in WAV format ready for playback or saving.
  /// - Throws: ``VOICEVOXError`` if the synthesis fails.
  func synthesize(
    audioQuery: AudioQuery,
    styleId: UInt32,
    options: VoicevoxSynthesisOptions = voicevox_make_default_synthesis_options()
  ) throws(VOICEVOXError) -> Data {
    // Convert AudioQuery to JSON string for the C API
    let jsonString = try audioQuery.toJSONString()

    var wavLength: UInt = 0
    var wavBuffer: UnsafeMutablePointer<UInt8>?

    let resultCode = voicevox_synthesizer_synthesis(
      pointer,
      jsonString,
      styleId,
      options,
      &wavLength,
      &wavBuffer
    )

    guard resultCode == 0, let wavBuffer, wavLength > 0 else {
      throw .synthesisFailed(
        text: nil,
        styleId: styleId,
        reason: "Audio synthesis failed with error code \(resultCode). Check style ID and voice model."
      )
    }

    defer { voicevox_wav_free(wavBuffer) }
    return Data(bytes: wavBuffer, count: Int(wavLength))
  }
}
