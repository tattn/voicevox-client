import Foundation

/// Represents a voice speaker with their available styles and metadata.
public struct VOICEVOXSpeaker: Codable, Equatable, Hashable, Sendable {
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
    public let type: String
  }
}
