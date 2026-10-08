import Foundation

/// Represents a voice speaker with their available styles and metadata.
public struct Speaker: Codable, Equatable, Hashable, Sendable {
  /// The unique identifier for this speaker.
  public let speakerUUID: UUID

  /// The display name of this speaker (e.g., "四国めたん", "ずんだもん").
  public let name: String

  /// The version of this speaker's voice model.
  public let version: String

  /// The display order for this speaker in the list.
  public let order: Int

  /// The available voice styles for this speaker.
  public let styles: [Style]

  private enum CodingKeys: String, CodingKey {
    case speakerUUID = "speaker_uuid"
    case name
    case version
    case order
    case styles
  }

  /// Represents a speaker's voice style with its metadata.
  public struct Style: Codable, Equatable, Hashable, Sendable {
    /// The unique identifier for this style.
    public let id: UInt32

    /// The display name of this style (e.g., "ノーマル", "あまあま").
    public let name: String

    /// The display order for this style within its speaker.
    public let order: Int

    /// The type of this style (e.g., "talk").
    ///
    /// Use ``styleType`` for a typed representation.
    public let type: String

    /// The typed representation of ``type``, or `nil` if the type is unknown to this library.
    public var styleType: StyleType? {
      StyleType(rawValue: type)
    }
  }

  /// The type of a voice style, which determines the available operations.
  public enum StyleType: String, Codable, Sendable, CaseIterable {
    /// Supports creating audio queries and synthesizing speech.
    case talk

    /// Supports creating frame audio queries for singing synthesis.
    case singingTeacher = "singing_teacher"

    /// Supports singing synthesis from frame audio queries.
    case frameDecode = "frame_decode"

    /// Supports both creating frame audio queries and singing synthesis.
    case sing

    /// Supports everything ``talk`` does, and streaming speech synthesis.
    case streamingTalk = "streaming_talk"
  }
}
