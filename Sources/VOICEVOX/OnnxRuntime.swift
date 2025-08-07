import voicevox_core

/// Wrapper for OnnxRuntime.
final class OnnxRuntime {
  let pointer: OpaquePointer

  init() throws(VOICEVOXError) {
    var onnxruntime = voicevox_onnxruntime_get()
    let resultCode = voicevox_onnxruntime_init_once(&onnxruntime)

    guard resultCode == 0, let onnxruntime else {
      throw .initializationFailed(
        message: "OnnxRuntime initialization failed",
        underlyingErrorCode: Int(resultCode)
      )
    }

    self.pointer = onnxruntime
  }

  deinit {
    // OnnxRuntime doesn't need explicit cleanup in the current API
  }
}
