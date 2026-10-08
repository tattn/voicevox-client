import Foundation
import voicevox_common

/// JSON bridging between Swift values and the VOICEVOX Core C API.
enum CoreJSON {
  /// Encodes a value into a JSON string for the C API.
  static func encode(
    _ value: some Encodable,
    orThrow makeError: (String) -> VOICEVOXError
  ) throws(VOICEVOXError) -> String {
    do {
      return String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    } catch {
      throw makeError("Failed to encode JSON: \(error.localizedDescription)")
    }
  }

  /// Decodes a JSON string returned by the C API and frees it.
  static func decodeAndFree<T: Decodable>(
    _ type: T.Type,
    from jsonPointer: UnsafeMutablePointer<CChar>,
    orThrow makeError: (String) -> VOICEVOXError
  ) throws(VOICEVOXError) -> T {
    defer { voicevox_json_free(jsonPointer) }
    do {
      return try JSONDecoder().decode(type, from: Data(bytes: jsonPointer, count: strlen(jsonPointer)))
    } catch {
      throw makeError("Failed to decode JSON: \(error.localizedDescription)")
    }
  }

  /// Validates a value with a VOICEVOX Core validation function.
  static func validate(
    _ value: some Encodable,
    kind: VOICEVOXError.QueryKind,
    with validator: (String) -> Int32
  ) throws(VOICEVOXError) {
    let json = try encode(value) { .invalidQuery(kind: kind, reason: $0) }
    let resultCode = validator(json)
    guard resultCode == 0 else {
      throw VOICEVOXError.queryError(for: resultCode) ?? .invalidQuery(kind: kind, reason: nil)
    }
  }
}

extension VOICEVOXError {
  /// Maps a result code that represents an invalid query to the corresponding error.
  ///
  /// - Returns: `nil` if the result code does not represent an invalid query.
  static func queryError(for resultCode: Int32) -> VOICEVOXError? {
    let kind: QueryKind
    switch resultCode {
    case Int32(VOICEVOX_RESULT_INVALID_AUDIO_QUERY_ERROR.rawValue):
      kind = .audioQuery
    case Int32(VOICEVOX_RESULT_INVALID_ACCENT_PHRASE_ERROR.rawValue):
      kind = .accentPhrase
    case Int32(VOICEVOX_RESULT_INVALID_MORA_ERROR.rawValue):
      kind = .mora
    case Int32(VOICEVOX_RESULT_INVALID_SCORE_ERROR.rawValue):
      kind = .score
    case Int32(VOICEVOX_RESULT_INVALID_NOTE_ERROR.rawValue):
      kind = .note
    case Int32(VOICEVOX_RESULT_INVALID_FRAME_AUDIO_QUERY_ERROR.rawValue):
      kind = .frameAudioQuery
    case Int32(VOICEVOX_RESULT_INVALID_FRAME_PHONEME_ERROR.rawValue):
      kind = .framePhoneme
    case Int32(VOICEVOX_RESULT_INCOMPATIBLE_QUERIES_ERROR.rawValue):
      return .incompatibleQueries(reason: message(for: resultCode))
    default:
      return nil
    }
    return .invalidQuery(kind: kind, reason: message(for: resultCode))
  }
}
