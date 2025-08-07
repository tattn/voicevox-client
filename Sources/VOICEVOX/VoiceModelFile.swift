import Foundation
import voicevox_core

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
    lhs.rawValue.0 == rhs.rawValue.0 && lhs.rawValue.1 == rhs.rawValue.1 && lhs.rawValue.2 == rhs.rawValue.2
      && lhs.rawValue.3 == rhs.rawValue.3 && lhs.rawValue.4 == rhs.rawValue.4 && lhs.rawValue.5 == rhs.rawValue.5
      && lhs.rawValue.6 == rhs.rawValue.6 && lhs.rawValue.7 == rhs.rawValue.7 && lhs.rawValue.8 == rhs.rawValue.8
      && lhs.rawValue.9 == rhs.rawValue.9 && lhs.rawValue.10 == rhs.rawValue.10 && lhs.rawValue.11 == rhs.rawValue.11
      && lhs.rawValue.12 == rhs.rawValue.12 && lhs.rawValue.13 == rhs.rawValue.13 && lhs.rawValue.14 == rhs.rawValue.14
      && lhs.rawValue.15 == rhs.rawValue.15
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.0)
    hasher.combine(rawValue.1)
    hasher.combine(rawValue.2)
    hasher.combine(rawValue.3)
    hasher.combine(rawValue.4)
    hasher.combine(rawValue.5)
    hasher.combine(rawValue.6)
    hasher.combine(rawValue.7)
    hasher.combine(rawValue.8)
    hasher.combine(rawValue.9)
    hasher.combine(rawValue.10)
    hasher.combine(rawValue.11)
    hasher.combine(rawValue.12)
    hasher.combine(rawValue.13)
    hasher.combine(rawValue.14)
    hasher.combine(rawValue.15)
  }
}

/// Wrapper for VoiceModelFile resource management.
final class VoiceModelFile {
  let pointer: OpaquePointer
  let url: URL
  let modelID: VoiceModelID

  init(url: URL) throws(VOICEVOXError) {
    var voiceModelFile: OpaquePointer?
    let openResultCode = voicevox_voice_model_file_open(url.path(), &voiceModelFile)

    guard openResultCode == 0, let voiceModelFile else {
      throw .voiceModelLoadFailed(
        path: url.path(),
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
