// see: https://github.com/VOICEVOX/voicevox_core/issues/975

import Foundation
import voicevox_common

/// Represents an audio query for speech synthesis.
/// This structure contains all parameters needed to generate speech audio from text.
public struct AudioQuery: Codable, Sendable, Equatable {
  /// Represents a mora (phonetic unit) in Japanese speech synthesis.
  /// A mora is a fundamental timing unit in Japanese phonology.
  public struct Mora: Codable, Sendable, Equatable {
    /// The text representation of the mora
    public var text: String

    /// The consonant sound (optional)
    public var consonant: String?

    /// The length of the consonant sound in seconds (optional)
    public var consonantLength: Float?

    /// The vowel sound
    public var vowel: String

    /// The length of the vowel sound in seconds
    public var vowelLength: Float

    /// The pitch of the mora in Hz
    public var pitch: Float

    private enum CodingKeys: String, CodingKey {
      case text
      case consonant
      case consonantLength = "consonant_length"
      case vowel
      case vowelLength = "vowel_length"
      case pitch
    }

    /// Creates a new Mora with the specified parameters.
    ///
    /// - Parameters:
    ///   - text: The text representation of the mora
    ///   - consonant: The consonant sound (optional)
    ///   - consonantLength: The length of the consonant sound in seconds (optional)
    ///   - vowel: The vowel sound
    ///   - vowelLength: The length of the vowel sound in seconds
    ///   - pitch: The pitch of the mora in Hz
    public init(
      text: String,
      consonant: String? = nil,
      consonantLength: Float? = nil,
      vowel: String,
      vowelLength: Float,
      pitch: Float
    ) {
      self.text = text
      self.consonant = consonant
      self.consonantLength = consonantLength
      self.vowel = vowel
      self.vowelLength = vowelLength
      self.pitch = pitch
    }
  }

  /// Represents an accent phrase in Japanese speech synthesis.
  /// An accent phrase is a phonological unit that contains one or more moras with a specific accent pattern.
  public struct AccentPhrase: Codable, Sendable, Equatable {
    /// Array of moras that make up the phrase
    public var moras: [Mora]

    /// The accent position in the phrase (0 means no accent, 1+ indicates mora position)
    public var accent: Int

    /// Optional pause mora at the end of the phrase
    public var pauseMora: Mora?

    /// Whether this phrase is interrogative (affects intonation)
    public var isInterrogative: Bool

    private enum CodingKeys: String, CodingKey {
      case moras
      case accent
      case pauseMora = "pause_mora"
      case isInterrogative = "is_interrogative"
    }

    /// Creates a new AccentPhrase with the specified parameters.
    ///
    /// - Parameters:
    ///   - moras: Array of moras that make up the phrase
    ///   - accent: The accent position in the phrase (0 means no accent, 1+ indicates mora position)
    ///   - pauseMora: Optional pause mora at the end of the phrase
    ///   - isInterrogative: Whether this phrase is interrogative (affects intonation)
    public init(
      moras: [Mora],
      accent: Int,
      pauseMora: Mora? = nil,
      isInterrogative: Bool = false
    ) {
      self.moras = moras
      self.accent = accent
      self.pauseMora = pauseMora
      self.isInterrogative = isInterrogative
    }
  }

  /// Array of accent phrases that make up the query
  public var accentPhrases: [AccentPhrase]

  /// Speed scale factor (1.0 = normal speed, >1.0 = faster, <1.0 = slower)
  public var speedScale: Float

  /// Pitch scale adjustment (1.0 = no change, >1.0 = higher pitch, <1.0 = lower pitch)
  public var pitchScale: Float

  /// Intonation scale factor (1.0 = normal intonation, >1.0 = more expressive, <1.0 = flatter)
  public var intonationScale: Float

  /// Volume scale factor (1.0 = normal volume, >1.0 = louder, <1.0 = quieter)
  public var volumeScale: Float

  /// Length of pre-phoneme pause in seconds
  public var prePhonemeLength: Float

  /// Length of post-phoneme pause in seconds
  public var postPhonemeLength: Float

  /// Output sampling rate in Hz (typically 24000)
  public var outputSamplingRate: Int

  /// Whether to output in stereo (true) or mono (false)
  public var outputStereo: Bool

  /// Kana representation of the text (optional)
  public var kana: String?

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
