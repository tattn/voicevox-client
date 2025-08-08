import voicevox_core

/// Wrapper for Synthesizer.
final class Synthesizer {
  let pointer: OpaquePointer

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
  }

  deinit {
    voicevox_synthesizer_delete(pointer)
  }

  func loadVoiceModel(from file: VoiceModelFile) throws(VOICEVOXError) {
    // Load the model into the synthesizer
    let loadResultCode = voicevox_synthesizer_load_voice_model(pointer, file.pointer)

    guard loadResultCode == 0 else {
      throw .voiceModelLoadFailed(
        path: file.url.path(),
        reason: "Failed to load voice model into synthesizer (error code: \(loadResultCode))"
      )
    }
  }

  func unloadVoiceModel(modelID: VoiceModelID) throws(VOICEVOXError) {
    let unloadResultCode = modelID.withPointer { tuplePtr in
      voicevox_synthesizer_unload_voice_model(pointer, tuplePtr)
    }

    guard unloadResultCode == 0 else {
      throw .voiceModelLoadFailed(
        path: "",
        reason: "Failed to unload voice model from synthesizer (error code: \(unloadResultCode))"
      )
    }
  }

  func isVoiceModelLoaded(modelID: VoiceModelID) -> Bool {
    modelID.withPointer { tuplePtr in
      voicevox_synthesizer_is_loaded_voice_model(pointer, tuplePtr)
    }
  }
}
