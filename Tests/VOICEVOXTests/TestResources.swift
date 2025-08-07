import Foundation
import Testing

@testable import VOICEVOX

/// Shared test resource utilities for VOICEVOX tests.
enum TestResources {
  /// The base path to test resources directory.
  static var basePath: String {
    guard let resourceURL = Bundle.module.resourceURL else {
      fatalError("Unable to find test resources bundle")
    }
    return resourceURL.appending(component: "lib").path()
  }

  /// The path to the OpenJTalk dictionary directory.
  static var openJTalkPath: String {
    "\(basePath)/open_jtalk_dic_utf_8"
  }

  /// URL to the OpenJTalk dictionary directory.
  static var openJTalkURL: URL {
    URL(fileURLWithPath: openJTalkPath)
  }

  /// The path to the primary test voice model file.
  static var primaryVoiceModelPath: String {
    "\(basePath)/vvms/0.vvm"
  }

  /// URL to the primary test voice model file.
  static var primaryVoiceModelURL: URL {
    URL(fileURLWithPath: primaryVoiceModelPath)
  }

  /// Returns a URL for a voice model with the specified ID.
  ///
  /// - Parameter id: The voice model ID (e.g., 0, 1, 2, etc.)
  /// - Returns: URL to the voice model file
  static func voiceModelURL(id: Int) -> URL {
    URL(fileURLWithPath: "\(basePath)/vvms/\(id).vvm")
  }

  /// Creates a standard test configuration with OpenJTalk dictionary.
  ///
  /// - Parameters:
  ///   - accelerationMode: The acceleration mode to use. Defaults to `.cpu`.
  ///   - cpuNumThreads: The number of CPU threads. Defaults to 2.
  /// - Returns: A configured `VOICEVOXConfiguration` for testing
  static func createTestConfiguration(
    accelerationMode: VOICEVOXConfiguration.AccelerationMode = .cpu,
    cpuNumThreads: UInt16 = 2
  ) -> VOICEVOXConfiguration {
    VOICEVOXConfiguration(
      openJTalkDictionaryURL: openJTalkURL,
      accelerationMode: accelerationMode,
      cpuNumThreads: cpuNumThreads
    )
  }

  /// Verifies that required test resources exist.
  ///
  /// - Throws: Test failure if resources are not found
  static func verifyResourcesExist() throws {
    #expect(
      FileManager.default.fileExists(atPath: openJTalkPath),
      "OpenJTalk dictionary not found at \(openJTalkPath)"
    )
    #expect(
      FileManager.default.fileExists(atPath: primaryVoiceModelPath),
      "Primary voice model not found at \(primaryVoiceModelPath)"
    )
  }

  /// Verifies that a specific voice model exists.
  ///
  /// - Parameter id: The voice model ID to check
  /// - Throws: Test failure if the voice model is not found
  static func verifyVoiceModelExists(id: Int) throws {
    let modelURL = voiceModelURL(id: id)
    #expect(
      FileManager.default.fileExists(atPath: modelURL.path()),
      "Voice model \(id) not found at \(modelURL.path())"
    )
  }
}
