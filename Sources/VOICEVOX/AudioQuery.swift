// see: https://github.com/VOICEVOX/voicevox_core/issues/975

import Foundation
import voicevox_common

/// Represents an audio query for speech synthesis.
/// This structure contains all parameters needed to generate speech audio from text.
public struct AudioQuery: Codable, Sendable {
  /// Represents a mora (phonetic unit) in Japanese speech synthesis.
  /// A mora is a fundamental timing unit in Japanese phonology.
  public struct Mora: Codable, Sendable {
    /// The text representation of the mora
    public let text: String

    /// The consonant sound (optional)
    public let consonant: String?

    /// The length of the consonant sound in seconds (optional)
    public let consonantLength: Float?

    /// The vowel sound
    public let vowel: String

    /// The length of the vowel sound in seconds
    public let vowelLength: Float

    /// The pitch of the mora in Hz
    public let pitch: Float

    private enum CodingKeys: String, CodingKey {
      case text
      case consonant
      case consonantLength = "consonant_length"
      case vowel
      case vowelLength = "vowel_length"
      case pitch
    }
  }

  /// Represents a pause mora in speech synthesis.
  /// Pause moras are used to represent silence or pauses between speech segments.
  public struct PauseMora: Codable, Sendable {
    /// The text representation (typically empty for pauses)
    public let text: String

    /// The consonant sound (optional)
    public let consonant: String?

    /// The length of the consonant sound in seconds (optional)
    public let consonantLength: Float?

    /// The vowel sound
    public let vowel: String

    /// The length of the vowel sound in seconds
    public let vowelLength: Float

    /// The pitch in Hz (typically 0 for pauses)
    public let pitch: Float

    private enum CodingKeys: String, CodingKey {
      case text
      case consonant
      case consonantLength = "consonant_length"
      case vowel
      case vowelLength = "vowel_length"
      case pitch
    }
  }

  /// Represents an accent phrase in Japanese speech synthesis.
  /// An accent phrase is a phonological unit that contains one or more moras with a specific accent pattern.
  public struct AccentPhrase: Codable, Sendable {
    /// Array of moras that make up the phrase
    public let moras: [Mora]

    /// The accent position in the phrase (0 means no accent, 1+ indicates mora position)
    public let accent: Int

    /// Optional pause mora at the end of the phrase
    public let pauseMora: PauseMora?

    /// Whether this phrase is interrogative (affects intonation)
    public let isInterrogative: Bool

    private enum CodingKeys: String, CodingKey {
      case moras
      case accent
      case pauseMora = "pause_mora"
      case isInterrogative = "is_interrogative"
    }
  }

  /// Array of accent phrases that make up the query
  public let accentPhrases: [AccentPhrase]

  /// Speed scale factor (1.0 = normal speed, >1.0 = faster, <1.0 = slower)
  public let speedScale: Float

  /// Pitch scale adjustment (1.0 = no change, >1.0 = higher pitch, <1.0 = lower pitch)
  public let pitchScale: Float

  /// Intonation scale factor (1.0 = normal intonation, >1.0 = more expressive, <1.0 = flatter)
  public let intonationScale: Float

  /// Volume scale factor (1.0 = normal volume, >1.0 = louder, <1.0 = quieter)
  public let volumeScale: Float

  /// Length of pre-phoneme pause in seconds
  public let prePhonemeLength: Float

  /// Length of post-phoneme pause in seconds
  public let postPhonemeLength: Float

  /// Output sampling rate in Hz (typically 24000)
  public let outputSamplingRate: Int

  /// Whether to output in stereo (true) or mono (false)
  public let outputStereo: Bool

  /// Kana representation of the text (optional)
  public let kana: String?

  private enum CodingKeys: String, CodingKey {
    case accentPhrases = "accent_phrases"
    case speedScale
    case pitchScale
    case intonationScale
    case volumeScale
    case prePhonemeLength
    case postPhonemeLength
    case outputSamplingRate
    case outputStereo
    case kana
  }

  /// Creates an AudioQuery with all parameters specified.
  ///
  /// - Parameters:
  ///   - accentPhrases: The accent phrases that make up the speech
  ///   - speedScale: Speed multiplier (1.0 = normal, >1.0 = faster, <1.0 = slower)
  ///   - pitchScale: Pitch adjustment (1.0 = no change, >1.0 = higher, <1.0 = lower)
  ///   - intonationScale: Intonation expressiveness (1.0 = normal, >1.0 = more expressive)
  ///   - volumeScale: Volume multiplier (1.0 = normal, >1.0 = louder, <1.0 = quieter)
  ///   - prePhonemeLength: Silence duration before speech in seconds
  ///   - postPhonemeLength: Silence duration after speech in seconds
  ///   - outputSamplingRate: Audio sampling rate in Hz
  ///   - outputStereo: Whether to generate stereo (true) or mono (false) output
  ///   - kana: Optional kana representation of the input text
  public init(
    accentPhrases: [AccentPhrase],
    speedScale: Float,
    pitchScale: Float,
    intonationScale: Float,
    volumeScale: Float,
    prePhonemeLength: Float,
    postPhonemeLength: Float,
    outputSamplingRate: Int,
    outputStereo: Bool,
    kana: String?
  ) {
    self.accentPhrases = accentPhrases
    self.speedScale = speedScale
    self.pitchScale = pitchScale
    self.intonationScale = intonationScale
    self.volumeScale = volumeScale
    self.prePhonemeLength = prePhonemeLength
    self.postPhonemeLength = postPhonemeLength
    self.outputSamplingRate = outputSamplingRate
    self.outputStereo = outputStereo
    self.kana = kana
  }

  /// Creates an AudioQuery from JSON data.
  ///
  /// - Parameter jsonData: The JSON data to decode
  /// - Throws: `VOICEVOXError.synthesisFailed` if decoding fails
  public init(from jsonData: Data) throws(VOICEVOXError) {
    do {
      self = try JSONDecoder().decode(AudioQuery.self, from: jsonData)
    } catch {
      throw .synthesisFailed(
        text: "[JSON decode]",
        styleId: 0,
        reason: "Failed to decode AudioQuery from JSON: \(error.localizedDescription)"
      )
    }
  }

  /// Converts the AudioQuery to JSON data.
  ///
  /// - Returns: The encoded JSON data
  /// - Throws: `VOICEVOXError.synthesisFailed` if encoding fails
  public func toJSONData() throws(VOICEVOXError) -> Data {
    do {
      return try JSONEncoder().encode(self)
    } catch {
      throw .synthesisFailed(
        text: "[JSON encode]",
        styleId: 0,
        reason: "Failed to encode AudioQuery to JSON: \(error.localizedDescription)"
      )
    }
  }

  /// Converts the AudioQuery to a JSON string.
  ///
  /// - Returns: The encoded JSON string
  /// - Throws: `VOICEVOXError.synthesisFailed` if encoding or string conversion fails
  public func toJSONString() throws(VOICEVOXError) -> String {
    let data = try toJSONData()
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw .synthesisFailed(
        text: "[JSON string conversion]",
        styleId: 0,
        reason: "Failed to convert encoded AudioQuery data to UTF-8 string"
      )
    }
    return jsonString
  }
}

// MARK: - VOICEVOX Core Integration

extension AudioQuery {
  /// Creates an AudioQuery from accent phrases using the VOICEVOX Core API.
  ///
  /// This initializer interfaces with the native VOICEVOX Core library to generate
  /// an audio query from pre-processed accent phrases.
  ///
  /// - Parameters:
  ///   - accentPhrasesJson: Pointer to a null-terminated C string containing JSON-encoded accent phrases
  ///   - text: The original input text (used for error context)
  ///   - styleId: The voice style identifier (used for error context)
  ///
  /// - Throws: `VOICEVOXError.synthesisFailed` if the Core API call fails or JSON parsing fails
  init(
    accentPhrasesJson: UnsafeMutablePointer<CChar>,
    text: String,
    styleId: UInt32
  ) throws(VOICEVOXError) {
    var audioQueryJson: UnsafeMutablePointer<CChar>?
    let resultCode = voicevox_audio_query_create_from_accent_phrases(
      accentPhrasesJson,
      &audioQueryJson
    )

    guard resultCode == 0, let audioQueryJson else {
      throw .synthesisFailed(
        text: text,
        styleId: styleId,
        reason: "VOICEVOX Core failed to create audio query from accent phrases (error code: \(resultCode))"
      )
    }

    defer { voicevox_json_free(audioQueryJson) }

    self = try AudioQuery(from: Data(bytes: audioQueryJson, count: strlen(audioQueryJson)))
  }
}
