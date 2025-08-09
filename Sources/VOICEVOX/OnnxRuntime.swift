import Foundation
import voicevox_common

/// Wrapper for OnnxRuntime.
final class OnnxRuntime {
  let pointer: OpaquePointer

  #if os(iOS)
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
  #else
  init(url: URL) throws(VOICEVOXError) {
    var onnxruntime = voicevox_onnxruntime_get()
    let libURL = url.appending(path: String(cString: voicevox_get_onnxruntime_lib_versioned_filename()))
    let resultCode = libURL.absoluteURL.path()
      .withCString { filename in
        var load_ort_options = voicevox_make_default_load_onnxruntime_options()
        load_ort_options.filename = filename
        return voicevox_onnxruntime_load_once(load_ort_options, &onnxruntime)
      }

    guard resultCode == 0, let onnxruntime else {
      throw .initializationFailed(
        message: "OnnxRuntime initialization failed",
        underlyingErrorCode: Int(resultCode)
      )
    }

    self.pointer = onnxruntime
  }
  #endif

  deinit {
    // OnnxRuntime doesn't need explicit cleanup in the current API
  }
}
