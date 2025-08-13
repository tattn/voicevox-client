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

/// Wrapper for VoiceModelFile resource management.
final class VoiceModelFile {
  let pointer: OpaquePointer
  let url: URL
  let modelID: VoiceModelID

  init(url: URL) throws(VOICEVOXError) {
    var voiceModelFile: OpaquePointer?
    let openResultCode = voicevox_voice_model_file_open(url.absoluteURL.path(), &voiceModelFile)

    guard openResultCode == 0, let voiceModelFile else {
      throw .voiceModelLoadFailed(
        path: url.absoluteURL.path(),
        reason: "Failed to open voice model file (error code: \(openResultCode))"
      )
    }

    self.pointer = voiceModelFile
    self.url = url
    self.modelID = VoiceModelID(voiceModelFile: voiceModelFile)
  }

  deinit {
    voicevox_voice_model_file_delete(pointer)
  }
}
