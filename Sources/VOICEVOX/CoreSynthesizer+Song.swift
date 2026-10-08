import Foundation
import voicevox_common

// MARK: - Singing Synthesis

extension CoreSynthesizer {
  /// Creates a frame audio query for singing synthesis from a score.
  ///
  /// - Parameters:
  ///   - score: The score to sing.
  ///   - styleId: The style ID of a `singing_teacher` or `sing` style.
  /// - Returns: The frame audio query.
  /// - Throws: ``VOICEVOXError`` if the creation fails.
  func createSingFrameAudioQuery(score: Score, styleId: UInt32) throws(VOICEVOXError) -> FrameAudioQuery {
    let scoreJSON = try CoreJSON.encode(score) { .invalidQuery(kind: .score, reason: $0) }

    var frameAudioQueryJSON: UnsafeMutablePointer<CChar>?
    let resultCode = voicevox_synthesizer_create_sing_frame_audio_query(
      pointer,
      scoreJSON,
      VoicevoxStyleId(styleId),
      &frameAudioQueryJSON
    )

    guard resultCode == 0, let frameAudioQueryJSON else {
      throw songError(resultCode: resultCode, styleId: styleId, operation: "create frame audio query")
    }
    return try CoreJSON.decodeAndFree(FrameAudioQuery.self, from: frameAudioQueryJSON) {
      .synthesisFailed(text: nil, styleId: styleId, reason: $0)
    }
  }

  /// Creates the fundamental frequency of each frame from a score and a frame audio query.
  ///
  /// - Parameters:
  ///   - score: The score.
  ///   - frameAudioQuery: The frame audio query created from the score.
  ///   - styleId: The style ID of a `singing_teacher` or `sing` style.
  /// - Returns: The fundamental frequency of each frame.
  /// - Throws: ``VOICEVOXError`` if the creation fails.
  func createSingFrameF0(
    score: Score,
    frameAudioQuery: FrameAudioQuery,
    styleId: UInt32
  ) throws(VOICEVOXError) -> [Float] {
    try createSingFrameValues(
      score: score,
      frameAudioQuery: frameAudioQuery,
      styleId: styleId,
      operation: "create frame F0",
      function: voicevox_synthesizer_create_sing_frame_f0
    )
  }

  /// Creates the volume of each frame from a score and a frame audio query.
  ///
  /// - Parameters:
  ///   - score: The score.
  ///   - frameAudioQuery: The frame audio query created from the score.
  ///   - styleId: The style ID of a `singing_teacher` or `sing` style.
  /// - Returns: The volume of each frame.
  /// - Throws: ``VOICEVOXError`` if the creation fails.
  func createSingFrameVolume(
    score: Score,
    frameAudioQuery: FrameAudioQuery,
    styleId: UInt32
  ) throws(VOICEVOXError) -> [Float] {
    try createSingFrameValues(
      score: score,
      frameAudioQuery: frameAudioQuery,
      styleId: styleId,
      operation: "create frame volume",
      function: voicevox_synthesizer_create_sing_frame_volume
    )
  }

  /// Synthesizes singing voice from a frame audio query.
  ///
  /// - Parameters:
  ///   - frameAudioQuery: The frame audio query.
  ///   - styleId: The style ID of a `frame_decode` or `sing` style.
  /// - Returns: Audio data in WAV format.
  /// - Throws: ``VOICEVOXError`` if the synthesis fails.
  func synthesize(frameAudioQuery: FrameAudioQuery, styleId: UInt32) throws(VOICEVOXError) -> Data {
    let queryJSON = try CoreJSON.encode(frameAudioQuery) { .invalidQuery(kind: .frameAudioQuery, reason: $0) }

    var wavLength: UInt = 0
    var wavBuffer: UnsafeMutablePointer<UInt8>?
    let resultCode = voicevox_synthesizer_frame_synthesis(
      pointer,
      queryJSON,
      VoicevoxStyleId(styleId),
      &wavLength,
      &wavBuffer
    )

    guard resultCode == 0, let wavBuffer, wavLength > 0 else {
      throw songError(resultCode: resultCode, styleId: styleId, operation: "synthesize singing voice")
    }

    defer { voicevox_wav_free(wavBuffer) }
    return Data(bytes: wavBuffer, count: Int(wavLength))
  }

  // MARK: - Private Helper Methods

  private typealias SingFrameValuesFunction = (
    OpaquePointer?,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?,
    VoicevoxStyleId,
    UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
  ) -> Int32

  private func createSingFrameValues(
    score: Score,
    frameAudioQuery: FrameAudioQuery,
    styleId: UInt32,
    operation: String,
    function: SingFrameValuesFunction
  ) throws(VOICEVOXError) -> [Float] {
    let scoreJSON = try CoreJSON.encode(score) { .invalidQuery(kind: .score, reason: $0) }
    let queryJSON = try CoreJSON.encode(frameAudioQuery) { .invalidQuery(kind: .frameAudioQuery, reason: $0) }

    var valuesJSON: UnsafeMutablePointer<CChar>?
    let resultCode = function(pointer, scoreJSON, queryJSON, VoicevoxStyleId(styleId), &valuesJSON)

    guard resultCode == 0, let valuesJSON else {
      throw songError(resultCode: resultCode, styleId: styleId, operation: operation)
    }
    return try CoreJSON.decodeAndFree([Float].self, from: valuesJSON) {
      .synthesisFailed(text: nil, styleId: styleId, reason: $0)
    }
  }

  private func songError(resultCode: Int32, styleId: UInt32, operation: String) -> VOICEVOXError {
    VOICEVOXError.queryError(for: resultCode)
      ?? .synthesisFailed(
        text: nil,
        styleId: styleId,
        reason: "Failed to \(operation): \(VOICEVOXError.message(for: resultCode))"
      )
  }
}
