import Foundation
import voicevox_common

/// Wrapper for OpenJTalk.
final class OpenJTalk {
  let pointer: OpaquePointer

  init(dictionaryURL: URL) throws(VOICEVOXError) {
    let dictionaryPath = dictionaryURL.absoluteURL.path()

    // Attempt to create the OpenJTalk resource
    var openJTalk: OpaquePointer?
    let resultCode = voicevox_open_jtalk_rc_new(dictionaryPath, &openJTalk)

    guard resultCode == 0, let openJTalk else {
      throw .openJTalkLoadFailed(
        dictionaryURL: dictionaryURL.absoluteString,
        reason: "Failed to load dictionary with error code: \(resultCode)"
      )
    }

    self.pointer = openJTalk
  }

  deinit {
    voicevox_open_jtalk_rc_delete(pointer)
  }
}
