import Foundation
import voicevox_common

public struct VoiceModelID: Equatable, Hashable, Sendable {
  // swiftlint:disable:next large_tuple
  typealias RawValue = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )
  var rawValue: RawValue

  init(voiceModelFile: OpaquePointer) {
    rawValue = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    withUnsafeMutablePointer(to: &rawValue) { pointer in
      voicevox_voice_model_file_id(voiceModelFile, pointer)
    }
  }

  func withPointer<T>(body: (UnsafePointer<RawValue>) -> T) -> T {
    var rawValue = rawValue
    return withUnsafePointer(to: &rawValue) { pointer in
      body(pointer)
    }
  }

  public static func == (lhs: VoiceModelID, rhs: VoiceModelID) -> Bool {
    withUnsafeBytes(of: lhs.rawValue) { lhsBytes in
      withUnsafeBytes(of: rhs.rawValue) { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }

  public func hash(into hasher: inout Hasher) {
    withUnsafeBytes(of: rawValue) { bytes in
      hasher.combine(bytes: bytes)
    }
  }
}

/// The behavior when a voice model with the same ``VoiceModelID`` is already loaded.
public enum ExistingVoiceModelBehavior: Sendable, CaseIterable {
  /// Throws ``VOICEVOXError/voiceModelLoadFailed(path:reason:)``.
  case error

  /// Reloads the voice model.
  ///
  /// VOICEVOX Core keeps a large amount of CPU/GPU memory occupied after synthesizing long text at once.
  /// Reloading the voice model releases that memory.
  case reload

  /// Does nothing and keeps the loaded voice model.
  case skip

  var cValue: Int32 {
    switch self {
    case .error:
      Int32(VOICEVOX_ON_EXISTING_VOICE_MODEL_ID_ERROR.rawValue)
    case .reload:
      Int32(VOICEVOX_ON_EXISTING_VOICE_MODEL_ID_RELOAD.rawValue)
    case .skip:
      Int32(VOICEVOX_ON_EXISTING_VOICE_MODEL_ID_SKIP.rawValue)
    }
  }
}

/// Wrapper for VoiceModelFile resource management.
final class VoiceModelFile {
  let pointer: OpaquePointer
  let url: URL
  let modelID: VoiceModelID

  init(url: URL) throws(VOICEVOXError) {
    var voiceModelFile: OpaquePointer?
    let openResultCode = voicevox_voice_model_file_open(url.fileSystemPath, &voiceModelFile)

    guard openResultCode == 0, let voiceModelFile else {
      throw .voiceModelLoadFailed(
        path: url.fileSystemPath,
        reason: "Failed to open voice model file (error code: \(openResultCode))"
      )
    }

    self.pointer = voiceModelFile
    self.url = url
    self.modelID = VoiceModelID(voiceModelFile: voiceModelFile)
  }

  /// Returns speaker metadata from this voice model file without loading it into a synthesizer.
  func getSpeakers() throws(VOICEVOXError) -> [Speaker] {
    guard let jsonCString = voicevox_voice_model_file_create_metas_json(pointer) else {
      throw .voiceModelLoadFailed(
        path: url.fileSystemPath,
        reason: "Failed to retrieve speaker metadata from voice model file"
      )
    }
    defer { voicevox_json_free(jsonCString) }

    do {
      return try JSONDecoder().decode([Speaker].self, from: Data(bytes: jsonCString, count: strlen(jsonCString)))
    } catch {
      throw .voiceModelLoadFailed(
        path: url.fileSystemPath,
        reason: "Failed to parse speaker metadata: \(error.localizedDescription)"
      )
    }
  }

  deinit {
    voicevox_voice_model_file_delete(pointer)
  }
}
