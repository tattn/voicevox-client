import Foundation
import voicevox_core

/// The main synthesizer that provides thread-safe access to VOICEVOX TTS operations.
///
/// `VOICEVOXSynthesizer` is the main API for performing text-to-speech synthesis using VOICEVOX.
/// It directly integrates with the VOICEVOX Core C library, handling resource management,
/// initialization, and synthesis operations.
///
/// ## Thread Safety
///
/// As an actor, `VOICEVOXSynthesizer` automatically serializes all method calls, ensuring
/// thread-safe operation even when accessed from multiple concurrent contexts.
public actor VOICEVOXSynthesizer {
  /// The OnnxRuntime wrapper for neural network inference.
  private let onnxruntime: OnnxRuntime

  /// The OpenJTalk wrapper for text processing.
  private let openJTalk: OpenJTalk

  /// The native synthesizer wrapper from VOICEVOX Core.
  private let synthesizer: Synthesizer

  /// The synthesizer pointer for direct synthesis operations.
  var synthesizerPointer: SynthesizerPointer {
    SynthesizerPointer(synthesizer.pointer)
  }

  /// Creates and initializes a new synthesizer instance with the specified configuration.
  ///
  /// - Parameter configuration: The configuration settings specifying dictionary
  ///   paths, acceleration modes, and threading options.
  ///
  /// - Throws: `VOICEVOXError.initializationFailed` if any step of the
  ///   initialization process fails.
  ///
  /// - Important: This operation may take some time to complete, especially
  ///   on first initialization or with GPU acceleration enabled.
  public init(configuration: VOICEVOXConfiguration) async throws(VOICEVOXError) {
    // Initialize resources in the required dependency order
    // Each wrapper handles its own C resource cleanup in deinit
    self.onnxruntime = try OnnxRuntime()
    self.openJTalk = try OpenJTalk(dictionaryURL: configuration.openJTalkDictionaryURL)
    self.synthesizer = try Synthesizer(
      onnxruntime: onnxruntime,
      openJTalk: openJTalk,
      configuration: configuration
    )
  }

  /// Loads a voice model from the specified file URL.
  ///
  /// Voice models contain the neural network weights for specific speakers and voices.
  /// Multiple models can be loaded simultaneously to provide access to different
  /// voices and speaking styles.
  ///
  /// - Parameter url: The file URL to the voice model (.vvm file).
  ///
  /// - Returns: The unique identifier of the loaded voice model.
  ///
  /// - Throws: `VOICEVOXError.voiceModelLoadFailed` if the model cannot be loaded.
  ///
  /// - Note: If the same model is already loaded, this operation returns the existing
  ///   model ID and will not throw an error.
  @discardableResult
  public func loadVoiceModel(from url: URL) async throws(VOICEVOXError) -> VoiceModelID {
    // Open and load the voice model file
    let voiceModelFile = try VoiceModelFile(url: url)
    let modelID = voiceModelFile.modelID

    // Skip if already loaded
    guard !synthesizer.isVoiceModelLoaded(modelID: modelID) else {
      return modelID
    }

    // Load the model into the synthesizer
    try synthesizer.loadVoiceModel(from: voiceModelFile)
    return modelID
  }

  /// Unloads a previously loaded voice model.
  ///
  /// - Parameter modelID: The unique identifier of the voice model to unload.
  ///
  /// - Throws: `VOICEVOXError` if the model cannot be unloaded.
  ///
  /// - Note: This method will silently succeed if the model was not previously loaded.
  public func unloadVoiceModel(modelID: VoiceModelID) async throws(VOICEVOXError) {
    guard synthesizer.isVoiceModelLoaded(modelID: modelID) else {
      // Model is not loaded, nothing to do
      return
    }

    // Unload the model from the synthesizer
    try synthesizer.unloadVoiceModel(modelID: modelID)
  }

  /// Retrieves metadata for all currently loaded voice models.
  ///
  /// This method fetches information about all speakers and their available styles
  /// from the loaded voice models. Each speaker includes their unique identifier,
  /// name, version, and a list of available voice styles.
  ///
  /// - Returns: An array of `VOICEVOXSpeaker` objects containing metadata for all loaded models.
  ///
  /// - Throws: `VOICEVOXError` if the metadata cannot be retrieved or parsed.
  ///
  /// - Note: This method returns an empty array if no models are currently loaded.
  public func getSpeakers() async throws(VOICEVOXError) -> [VOICEVOXSpeaker] {
    // Get JSON metadata from the synthesizer
    guard let jsonCString = voicevox_synthesizer_create_metas_json(synthesizerPointer.value) else {
      throw .synthesisFailed(text: "", styleId: 0, reason: "Failed to retrieve speaker metadata")
    }

    // Ensure proper cleanup of the allocated C string
    defer { voicevox_json_free(jsonCString) }

    // Convert C string to Swift String
    let jsonString = String(cString: jsonCString)

    // Decode to VOICEVOXSpeaker array
    do {
      let decoder = JSONDecoder()
      return try decoder.decode([VOICEVOXSpeaker].self, from: Data(jsonString.utf8))
    } catch {
      throw .synthesisFailed(
        text: "",
        styleId: 0,
        reason: "Failed to parse speaker metadata: \(error.localizedDescription)"
      )
    }
  }

  /// Synthesizes speech from text using the specified voice style.
  ///
  /// This method performs the core text-to-speech conversion, transforming the
  /// input text into audio data using the loaded voice models and specified style.
  ///
  /// - Parameters:
  ///   - text: The text to synthesize. Should be in Japanese for best results.
  ///   - styleId: The voice style identifier. This must correspond to a style
  ///     available in the currently loaded voice models.
  ///   - options: Additional synthesis options such as intonation settings.
  ///
  /// - Returns: Audio data in WAV format ready for playback or further processing.
  ///
  /// - Throws: `VOICEVOXError.invalidStyleId` if the style ID is not available,
  ///   or `VOICEVOXError.synthesisFailed` if the synthesis process fails.
  ///
  /// - Important: At least one voice model must be loaded before calling this method,
  ///   and the specified style ID must be valid for the loaded models.
  public func synthesize(
    text: String,
    styleId: UInt32,
    options: TTSOptions = .standard
  ) async throws(VOICEVOXError) -> Data {
    // Perform synthesis operation
    var wavLength: UInt = 0
    var wavBuffer: UnsafeMutablePointer<UInt8>?

    let resultCode = voicevox_synthesizer_tts(
      synthesizerPointer.value,
      text,
      VoicevoxStyleId(styleId),
      options.toVoicevoxTtsOptions(),
      &wavLength,
      &wavBuffer
    )

    return try processResult(
      text: text,
      styleId: styleId,
      wavBuffer: wavBuffer,
      length: wavLength,
      resultCode: resultCode
    )
  }

  /// Processes the synthesis result and returns audio data.
  private func processResult(
    text: String,
    styleId: UInt32,
    wavBuffer: UnsafeMutablePointer<UInt8>?,
    length: UInt,
    resultCode: Int32
  ) throws(VOICEVOXError) -> Data {
    // Check for synthesis errors
    guard resultCode == 0 else {
      // Based on VOICEVOX Core documentation, result code 1 typically indicates invalid speaker/style ID
      guard resultCode == 1 else {
        throw .synthesisFailed(
          text: text,
          styleId: styleId,
          reason: "Synthesis failed with error code: \(resultCode)"
        )
      }
      throw .invalidStyleId(styleId: styleId, availableStyleIds: nil)
    }

    // Ensure we have valid output
    guard let wavBuffer, length > 0 else {
      throw .synthesisFailed(
        text: text,
        styleId: styleId,
        reason: "No audio data was generated"
      )
    }

    // Clean up the buffer when done
    defer { voicevox_wav_free(wavBuffer) }

    // Create and return the audio data
    return Data(bytes: wavBuffer, count: Int(length))
  }
}
