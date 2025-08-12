import Foundation
import voicevox_common

/// The main synthesizer that provides thread-safe access to VOICEVOX TTS operations.
///
/// `Synthesizer` is the main API for performing text-to-speech synthesis using VOICEVOX.
/// It directly integrates with the VOICEVOX Core C library, handling resource management,
/// initialization, and synthesis operations.
public actor Synthesizer {
  /// The native synthesizer wrapper from VOICEVOX Core.
  private let synthesizer: CoreSynthesizer

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
    #if os(iOS)
    let onnxruntime = try OnnxRuntime()
    #else
    let onnxruntime = try OnnxRuntime(url: configuration.onnxruntimeDirectoryURL)
    #endif
    let openJTalk = try OpenJTalk(dictionaryURL: configuration.openJTalkDictionaryURL)
    self.synthesizer = try CoreSynthesizer(
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
  /// - Returns: An array of `Speaker` objects containing metadata for all loaded models.
  ///
  /// - Throws: `VOICEVOXError` if the metadata cannot be retrieved or parsed.
  ///
  /// - Note: This method returns an empty array if no models are currently loaded.
  public func getSpeakers() async throws(VOICEVOXError) -> [Speaker] {
    // Get JSON metadata from the synthesizer
    guard let jsonCString = voicevox_synthesizer_create_metas_json(synthesizer.pointer) else {
      throw .synthesisFailed(text: "", styleId: 0, reason: "Failed to retrieve speaker metadata")
    }

    // Ensure proper cleanup of the allocated C string
    defer { voicevox_json_free(jsonCString) }

    // Decode to Speaker array
    do {
      let decoder = JSONDecoder()
      return try decoder.decode([Speaker].self, from: Data(bytes: jsonCString, count: strlen(jsonCString)))
    } catch {
      throw .synthesisFailed(
        text: "",
        styleId: 0,
        reason: "Failed to parse speaker metadata: \(error.localizedDescription)"
      )
    }
  }

  /// Creates an audio query from text.
  ///
  /// This method analyzes the input text and generates an AudioQuery object containing
  /// all the necessary information for speech synthesis, including accent phrases,
  /// mora data, and synthesis parameters.
  ///
  /// - Parameters:
  ///   - text: The text to process. Should be in Japanese for best results.
  ///   - styleId: The voice style identifier. This must correspond to a style
  ///     available in the currently loaded voice models.
  ///
  /// - Returns: An `AudioQuery` object containing synthesis parameters.
  ///
  /// - Throws: `VOICEVOXError` if the audio query creation fails.
  ///
  /// - Note: This method allows for fine-grained control over the synthesis process
  ///   by exposing the intermediate AudioQuery representation.
  public func makeAudioQuery(
    text: String,
    styleId: UInt32
  ) async throws(VOICEVOXError) -> AudioQuery {
    try synthesizer.makeAudioQuery(text: text, styleId: styleId)
  }

  /// Synthesizes speech from an audio query.
  ///
  /// This method performs speech synthesis using a pre-generated AudioQuery object,
  /// allowing for custom modifications to synthesis parameters before generating audio.
  ///
  /// - Parameters:
  ///   - audioQuery: The audio query containing synthesis parameters.
  ///   - styleId: The voice style identifier. This must correspond to a style
  ///     available in the currently loaded voice models.
  ///   - options: Additional synthesis options (defaults to standard options).
  ///
  /// - Returns: Audio data in WAV format ready for playback or further processing.
  ///
  /// - Throws: `VOICEVOXError.invalidStyleId` if the style ID is not available,
  ///   or `VOICEVOXError.synthesisFailed` if the synthesis process fails.
  ///
  /// - Note: This method provides advanced control over synthesis by accepting
  ///   a pre-configured AudioQuery that can be modified before synthesis.
  public func synthesize(
    audioQuery: AudioQuery,
    styleId: UInt32,
    options: VoicevoxSynthesisOptions = voicevox_make_default_synthesis_options()
  ) async throws(VOICEVOXError) -> Data {
    try synthesizer.synthesize(audioQuery: audioQuery, styleId: styleId, options: options)
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
    // Convert TTSOptions to VoicevoxSynthesisOptions
    var synthOptions = voicevox_make_default_synthesis_options()
    synthOptions.enable_interrogative_upspeak = options.enableInterrogativeUpspeak

    let audioQuery = try synthesizer.makeAudioQuery(text: text, styleId: styleId)
    return try synthesizer.synthesize(audioQuery: audioQuery, styleId: styleId, options: synthOptions)
  }
}
