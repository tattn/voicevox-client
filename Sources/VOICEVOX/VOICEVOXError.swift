import Foundation

/// Errors that can occur during VOICEVOX operations.
///
/// This enum provides comprehensive error information for all types of failures
/// that may occur when using the VOICEVOX text-to-speech engine, from initialization
/// to synthesis operations.
public enum VOICEVOXError: LocalizedError, Sendable {
  /// Engine initialization failed.
  ///
  /// This error occurs when the VOICEVOX engine cannot be properly initialized,
  /// which may happen due to invalid configuration, missing dependencies,
  /// or system resource issues.
  ///
  /// - Parameter message: A detailed message describing the initialization failure.
  /// - Parameter underlyingErrorCode: Optional error code from the underlying system.
  case initializationFailed(message: String, underlyingErrorCode: Int? = nil)

  /// OpenJTalk dictionary loading failed.
  ///
  /// This error occurs when the specified OpenJTalk dictionary cannot be loaded,
  /// typically due to an invalid path, corrupted dictionary files, or insufficient
  /// file permissions.
  ///
  /// - Parameter dictionaryURL: The URL that was attempted to be loaded.
  /// - Parameter reason: Optional specific reason for the failure.
  case openJTalkLoadFailed(dictionaryURL: String, reason: String? = nil)

  /// Voice model loading failed.
  ///
  /// This error occurs when a voice model (.vvm file) cannot be loaded,
  /// which may happen due to file corruption, incompatible model format,
  /// or insufficient system resources.
  ///
  /// - Parameter path: The path to the voice model that failed to load.
  /// - Parameter reason: Optional specific reason for the failure.
  case voiceModelLoadFailed(path: String, reason: String? = nil)

  /// Synthesizer creation failed.
  ///
  /// This error occurs when the internal synthesizer component cannot be created,
  /// typically due to system resource constraints or configuration issues.
  ///
  /// - Parameter details: Optional additional details about the failure.
  case synthesizerCreationFailed(details: String? = nil)

  /// Voice synthesis operation failed.
  ///
  /// This error occurs when the text-to-speech synthesis process fails,
  /// which may happen due to invalid input text, missing voice models,
  /// or runtime errors during synthesis.
  ///
  /// - Parameter text: The text that was being synthesized (truncated if long).
  /// - Parameter styleId: The style ID that was being used.
  /// - Parameter reason: Optional specific reason for the synthesis failure.
  case synthesisFailed(text: String?, styleId: UInt32?, reason: String? = nil)

  /// Invalid or unavailable style ID.
  ///
  /// This error occurs when attempting to use a style ID that is not available
  /// in any of the currently loaded voice models.
  ///
  /// - Parameter styleId: The invalid style ID that was attempted.
  /// - Parameter availableStyleIds: Optional list of available style IDs.
  case invalidStyleId(styleId: UInt32, availableStyleIds: [UInt32]? = nil)

  /// User dictionary operation failed.
  ///
  /// This error occurs when operations on the user dictionary fail,
  /// such as adding, updating, removing words, or loading/saving the dictionary.
  ///
  /// - Parameter operation: The operation that failed (e.g., "add", "update", "remove", "load", "save").
  /// - Parameter details: Optional additional details about the failure.
  case userDictError(operation: String, details: String? = nil)

  /// Internal error occurred.
  ///
  /// This error occurs when an unexpected internal error happens.
  ///
  /// - Parameter details: Details about the internal error.
  case internalError(details: String)

  // MARK: - LocalizedError Implementation

  public var errorDescription: String? {
    switch self {
    case let .initializationFailed(message, errorCode):
      var description = "VOICEVOX initialization failed: \(message)"
      if let errorCode {
        description += " (Error code: \(errorCode))"
      }
      return description

    case let .openJTalkLoadFailed(dictionaryURL, reason):
      var description = "Failed to load OpenJTalk dictionary from: \(dictionaryURL)"
      if let reason {
        description += " - \(reason)"
      }
      return description

    case let .voiceModelLoadFailed(path, reason):
      var description = "Failed to load voice model from: \(path)"
      if let reason {
        description += " - \(reason)"
      }
      return description

    case let .synthesizerCreationFailed(details):
      var description = "Failed to create synthesizer"
      if let details {
        description += ": \(details)"
      }
      return description

    case let .synthesisFailed(text, styleId, reason):
      var description = "Voice synthesis failed"

      var context: [String] = []
      if let text {
        let truncatedText = text.count > 50 ? String(text.prefix(50)) + "..." : text
        context.append("text: \"\(truncatedText)\"")
      }
      if let styleId {
        context.append("styleId: \(styleId)")
      }
      if let reason {
        context.append("reason: \(reason)")
      }

      if !context.isEmpty {
        description += " (\(context.joined(separator: ", ")))"
      }
      return description

    case let .invalidStyleId(styleId, availableStyleIds):
      var description = "Invalid style ID: \(styleId)"
      if let availableStyleIds, !availableStyleIds.isEmpty {
        let availableIds = availableStyleIds.map(String.init).joined(separator: ", ")
        description += ". Available style IDs: \(availableIds)"
      }
      return description

    case let .userDictError(operation, details):
      var description = "User dictionary \(operation) operation failed"
      if let details {
        description += ": \(details)"
      }
      return description

    case let .internalError(details):
      return "Internal error: \(details)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .initializationFailed:
      "The VOICEVOX engine could not be initialized with the provided configuration"
    case .openJTalkLoadFailed:
      "The OpenJTalk dictionary is required for text processing but could not be loaded"
    case .voiceModelLoadFailed:
      "The voice model file may be corrupted or incompatible"
    case .synthesizerCreationFailed:
      "Insufficient system resources or invalid configuration"
    case .synthesisFailed:
      "The synthesis process encountered an unexpected error"
    case .invalidStyleId:
      "The requested voice style is not available in the loaded models"
    case .userDictError:
      "The user dictionary operation could not be completed"
    case .internalError:
      "An unexpected internal error occurred"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .initializationFailed:
      "Check the OpenJTalk dictionary path and ensure system requirements are met"
    case .openJTalkLoadFailed:
      "Verify the OpenJTalk dictionary path exists and contains valid dictionary files"
    case .voiceModelLoadFailed:
      "Check if the voice model file exists and is not corrupted"
    case .synthesizerCreationFailed:
      "Try reducing CPU thread count or switching acceleration mode"
    case .synthesisFailed:
      "Ensure voice models are loaded and the style ID is valid"
    case .invalidStyleId:
      "Load the appropriate voice model or use a valid style ID"
    case .userDictError:
      "Check the dictionary file format and permissions, or verify the word data is valid"
    case .internalError:
      "Please report this issue to the developers with the error details"
    }
  }
}
