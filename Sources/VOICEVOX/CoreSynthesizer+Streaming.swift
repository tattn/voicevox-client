import Foundation
import voicevox_common

// MARK: - Streaming Synthesis

extension CoreSynthesizer {
  /// Creates an intermediate representation of speech from an audio query.
  ///
  /// - Parameters:
  ///   - audioQuery: The audio query containing synthesis parameters.
  ///   - styleId: The style ID of a `streaming_talk` style.
  ///   - options: Additional synthesis options.
  /// - Returns: The audio feature to render.
  /// - Throws: ``VOICEVOXError`` if the creation fails.
  func createAudioFeature(
    audioQuery: AudioQuery,
    styleId: UInt32,
    options: VoicevoxSynthesisOptions
  ) throws(VOICEVOXError) -> AudioFeature {
    let jsonString = try audioQuery.toJSONString()

    var audioFeature: OpaquePointer?
    let resultCode = voicevox_synthesizer_create_audio_feature(
      pointer,
      jsonString,
      VoicevoxStyleId(styleId),
      options,
      &audioFeature
    )

    guard resultCode == 0, let audioFeature else {
      if resultCode == Int32(VOICEVOX_RESULT_STYLE_NOT_FOUND_ERROR.rawValue) {
        throw .invalidStyleId(styleId: styleId)
      }
      throw VOICEVOXError.queryError(for: resultCode)
        ?? .synthesisFailed(
          text: nil,
          styleId: styleId,
          reason: "Failed to create audio feature: \(VOICEVOXError.message(for: resultCode))"
        )
    }

    return AudioFeature(
      pointer: audioFeature,
      samplingRate: audioQuery.outputSamplingRate,
      isStereo: audioQuery.outputStereo
    )
  }

  /// Renders a range of frames of an audio feature.
  ///
  /// - Parameters:
  ///   - audioFeature: The audio feature to render.
  ///   - frames: The range of frames to render. It must be within `0...audioFeature.frameLength`.
  /// - Returns: 16-bit little-endian PCM without a WAV header.
  /// - Throws: ``VOICEVOXError`` if the rendering fails.
  func render(_ audioFeature: AudioFeature, frames: Range<Int>) throws(VOICEVOXError) -> Data {
    try withExtendedLifetime(audioFeature) { () throws(VOICEVOXError) -> Data in
      try render(Self.slice(of: audioFeature, frames: frames))
    }
  }

  /// - Important: The returned slice is valid only while `audioFeature` is alive.
  private static func slice(
    of audioFeature: AudioFeature,
    frames: Range<Int>
  ) throws(VOICEVOXError) -> VoicevoxAudioFeatureSlice {
    var slice = VoicevoxAudioFeatureSlice()
    let resultCode = voicevox_audio_feature_slice(
      audioFeature.pointer,
      UInt(frames.lowerBound),
      UInt(frames.upperBound),
      false,
      false,
      false,
      &slice
    )
    guard resultCode == 0 else {
      throw .synthesisFailed(
        text: nil,
        styleId: nil,
        reason: "Invalid frame range \(frames) for \(audioFeature.frameLength) frames: "
          + VOICEVOXError.message(for: resultCode)
      )
    }
    return slice
  }

  private func render(_ slice: VoicevoxAudioFeatureSlice) throws(VOICEVOXError) -> Data {
    var pcmLength: UInt = 0
    var pcm: UnsafeMutablePointer<UInt8>?
    let resultCode = voicevox_synthesizer_render(pointer, slice, &pcmLength, &pcm)

    guard resultCode == 0, let pcm else {
      throw .synthesisFailed(
        text: nil,
        styleId: nil,
        reason: "Failed to render audio feature: \(VOICEVOXError.message(for: resultCode))"
      )
    }

    // An empty result points to `voicevox_empty_bytes`, which must not be freed.
    guard pcmLength > 0 else { return Data() }
    defer { voicevox_bytes_free(pcm) }
    return Data(bytes: pcm, count: Int(pcmLength))
  }
}
