import Foundation
import voicevox_common

/// A musical score for singing synthesis.
///
/// The first note must be a rest.
/// See [the VOICEVOX Core user guide](https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/song.md)
/// for details.
public struct Score: Codable, Sendable, Equatable, Hashable {
  /// A note or a rest in a ``Score``.
  public struct Note: Codable, Sendable, Equatable, Hashable {
    /// An optional identifier copied to ``FrameAudioQuery/FramePhoneme/noteId``.
    ///
    /// It does not affect the synthesized voice.
    public var id: String?

    /// The MIDI note number (0...127, e.g. `60` for C4), or `nil` for a rest.
    public var key: Int?

    /// The lyric representing one mora in hiragana or katakana (e.g. `"ド"`), or an empty string for a rest.
    public var lyric: String

    /// The length in frames.
    ///
    /// One second is 93.75 frames. For example, one beat at 125 BPM is 45 frames.
    public var frameLength: Int

    private enum CodingKeys: String, CodingKey {
      case id
      case key
      case lyric
      case frameLength = "frame_length"
    }

    /// Creates a note or a rest.
    ///
    /// - Parameters:
    ///   - key: The MIDI note number (0...127), or `nil` for a rest.
    ///   - lyric: The lyric representing one mora in hiragana or katakana, or an empty string for a rest.
    ///   - frameLength: The length in frames.
    ///   - id: An optional identifier copied to ``FrameAudioQuery/FramePhoneme/noteId``.
    public init(key: Int?, lyric: String, frameLength: Int, id: String? = nil) {
      self.id = id
      self.key = key
      self.lyric = lyric
      self.frameLength = frameLength
    }

    /// Creates a rest.
    ///
    /// - Parameters:
    ///   - frameLength: The length in frames.
    ///   - id: An optional identifier copied to ``FrameAudioQuery/FramePhoneme/noteId``.
    /// - Returns: A note representing a rest.
    public static func rest(frameLength: Int, id: String? = nil) -> Note {
      Note(key: nil, lyric: "", frameLength: frameLength, id: id)
    }

    /// Whether this note is a rest.
    public var isRest: Bool {
      key == nil
    }

    /// Validates the note with VOICEVOX Core.
    ///
    /// A note is invalid if `key` is out of range, if `lyric` is not a single mora,
    /// or if only one of `key` and `lyric` represents a rest.
    ///
    /// - Throws: ``VOICEVOXError/invalidQuery(kind:reason:)`` if the note is invalid.
    public func validate() throws(VOICEVOXError) {
      try CoreJSON.validate(self, kind: .note) { voicevox_note_validate($0) }
    }
  }

  /// The notes of the score.
  ///
  /// The first note must be a rest.
  public var notes: [Note]

  /// Creates a score.
  ///
  /// - Parameter notes: The notes of the score. The first note must be a rest.
  public init(notes: [Note]) {
    self.notes = notes
  }

  /// Validates the score with VOICEVOX Core.
  ///
  /// A score is invalid if any of its notes is invalid, if it has no notes, or if its first note is not a rest.
  ///
  /// - Throws: ``VOICEVOXError/invalidQuery(kind:reason:)`` if the score is invalid.
  public func validate() throws(VOICEVOXError) {
    try CoreJSON.validate(self, kind: .score) { voicevox_score_validate($0) }
  }
}

/// A query for singing synthesis, created from a ``Score``.
public struct FrameAudioQuery: Codable, Sendable, Equatable, Hashable {
  /// A phoneme and its length in a ``FrameAudioQuery``.
  public struct FramePhoneme: Codable, Sendable, Equatable, Hashable {
    /// The phoneme (e.g. `"pau"`, `"d"`, `"o"`).
    public var phoneme: String

    /// The length in frames.
    public var frameLength: Int

    /// The ``Score/Note/id`` of the note this phoneme was created from.
    public var noteId: String?

    private enum CodingKeys: String, CodingKey {
      case phoneme
      case frameLength = "frame_length"
      case noteId = "note_id"
    }

    /// Creates a frame phoneme.
    ///
    /// - Parameters:
    ///   - phoneme: The phoneme.
    ///   - frameLength: The length in frames.
    ///   - noteId: The identifier of the note this phoneme belongs to.
    public init(phoneme: String, frameLength: Int, noteId: String? = nil) {
      self.phoneme = phoneme
      self.frameLength = frameLength
      self.noteId = noteId
    }

    /// Validates the frame phoneme with VOICEVOX Core.
    ///
    /// - Throws: ``VOICEVOXError/invalidQuery(kind:reason:)`` if the frame phoneme is invalid.
    public func validate() throws(VOICEVOXError) {
      try CoreJSON.validate(self, kind: .framePhoneme) { voicevox_frame_phoneme_validate($0) }
    }
  }

  /// The fundamental frequency of each frame.
  public var f0: [Float]

  /// The volume of each frame.
  public var volume: [Float]

  /// The phonemes.
  public var phonemes: [FramePhoneme]

  /// Volume scale factor (1.0 = normal volume).
  public var volumeScale: Float

  /// Output sampling rate in Hz (typically 24000).
  public var outputSamplingRate: Int

  /// Whether to output in stereo (true) or mono (false).
  public var outputStereo: Bool

  /// Creates a frame audio query.
  ///
  /// - Parameters:
  ///   - f0: The fundamental frequency of each frame.
  ///   - volume: The volume of each frame.
  ///   - phonemes: The phonemes.
  ///   - volumeScale: Volume scale factor.
  ///   - outputSamplingRate: Output sampling rate in Hz.
  ///   - outputStereo: Whether to output in stereo.
  public init(
    f0: [Float],
    volume: [Float],
    phonemes: [FramePhoneme],
    volumeScale: Float = 1,
    outputSamplingRate: Int = 24000,
    outputStereo: Bool = false
  ) {
    self.f0 = f0
    self.volume = volume
    self.phonemes = phonemes
    self.volumeScale = volumeScale
    self.outputSamplingRate = outputSamplingRate
    self.outputStereo = outputStereo
  }

  /// Validates the frame audio query with VOICEVOX Core.
  ///
  /// VOICEVOX Core logs a warning when `outputSamplingRate` is not `24000`.
  ///
  /// - Throws: ``VOICEVOXError/invalidQuery(kind:reason:)`` if the frame audio query is invalid.
  public func validate() throws(VOICEVOXError) {
    try CoreJSON.validate(self, kind: .frameAudioQuery) { voicevox_frame_audio_query_validate($0) }
  }

  /// Checks whether this query can be used with the score to create the fundamental frequency and the volume.
  ///
  /// - Parameter score: The score the query was created from.
  /// - Throws: ``VOICEVOXError/invalidQuery(kind:reason:)`` if the score or this query is invalid, or
  ///   ``VOICEVOXError/incompatibleQueries(reason:)`` if their phonemes do not match.
  public func ensureCompatible(with score: Score) throws(VOICEVOXError) {
    let scoreJSON = try CoreJSON.encode(score) { .invalidQuery(kind: .score, reason: $0) }
    let queryJSON = try CoreJSON.encode(self) { .invalidQuery(kind: .frameAudioQuery, reason: $0) }
    let resultCode = voicevox_ensure_compatible(scoreJSON, queryJSON)
    guard resultCode == 0 else {
      throw VOICEVOXError.queryError(for: resultCode)
        ?? .incompatibleQueries(reason: VOICEVOXError.message(for: resultCode))
    }
  }
}
