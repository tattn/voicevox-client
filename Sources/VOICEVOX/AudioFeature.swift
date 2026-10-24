import Foundation
import voicevox_common

// The underlying VOICEVOX Core object is never mutated after construction and may be read from any thread.
/// An intermediate representation of speech used for streaming synthesis.
///
/// Create it with ``Synthesizer/createAudioFeature(audioQuery:styleId:options:)``, which finishes quickly,
/// and then render it bit by bit with ``Synthesizer/render(_:frames:)``.
/// It requires a voice model whose style type is ``Speaker/StyleType/streamingTalk``.
///
/// See [the VOICEVOX Core user guide](https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/usage.md)
/// for details of streaming synthesis.
public final class AudioFeature: @unchecked Sendable {
  /// The number of frames per second.
  public static let frameRate: Double = VOICEVOX_FRAME_RATE

  /// The underlying C pointer to the audio feature.
  let pointer: OpaquePointer

  /// The total number of frames.
  public let frameLength: Int

  /// The sampling rate of the PCM rendered from this audio feature, in Hz.
  public let samplingRate: Int

  /// Whether the PCM rendered from this audio feature is stereo.
  public let isStereo: Bool

  /// The duration of the whole speech, in seconds.
  public var duration: TimeInterval {
    Double(frameLength) / Self.frameRate
  }

  init(pointer: OpaquePointer, samplingRate: Int, isStereo: Bool) {
    self.pointer = pointer
    self.frameLength = Int(voicevox_audio_feature_len(pointer))
    self.samplingRate = samplingRate
    self.isStereo = isStereo
  }

  deinit {
    voicevox_audio_feature_delete(pointer)
  }
}
