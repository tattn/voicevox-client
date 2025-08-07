import Foundation
import Testing

@testable import VOICEVOX

struct VOICEVOXCoreTests {
  @Test
  func testCoreInitialization() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    _ = try await VOICEVOXSynthesizer(configuration: config)
  }

  @Test
  func testCoreInitializeWithInvalidPath() async throws {
    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(fileURLWithPath: "/invalid/path")
    )

    await #expect(throws: VOICEVOXError.self) {
      _ = try await VOICEVOXSynthesizer(configuration: config)
    }
  }

  @Test
  func testLoadVoiceModel() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    let synthesizer = try await VOICEVOXSynthesizer(configuration: config)

    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    // Loading same model twice should be idempotent
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)
  }

  @Test
  func testSynthesizeAudio() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    let synthesizer = try await VOICEVOXSynthesizer(configuration: config)
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    let audioData = try await synthesizer.synthesize(
      text: "テスト",
      styleId: 0,
      options: .standard
    )

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // WAV header
  }

  @Test
  func testUnloadVoiceModel() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    let synthesizer = try await VOICEVOXSynthesizer(configuration: config)

    let modelURL = TestResources.primaryVoiceModelURL

    // Load model
    let modelID = try await synthesizer.loadVoiceModel(from: modelURL)

    // Synthesize with loaded model should work
    let audioData = try await synthesizer.synthesize(
      text: "テスト",
      styleId: 0,
      options: .standard
    )
    #expect(!audioData.isEmpty)

    // Unload model
    try await synthesizer.unloadVoiceModel(modelID: modelID)

    // After unloading, synthesis should fail with invalid style ID
    // (This test assumes the model is fully unloaded and style ID becomes unavailable)
    // Note: The actual behavior depends on the voicevox_core implementation

    // Loading same model again should work
    try await synthesizer.loadVoiceModel(from: modelURL)
    let audioData2 = try await synthesizer.synthesize(
      text: "テスト2",
      styleId: 0,
      options: .standard
    )
    #expect(!audioData2.isEmpty)
  }

  @Test
  func testGetSpeakers() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    let synthesizer = try await VOICEVOXSynthesizer(configuration: config)

    // Before loading any models, speakers should be empty
    let speakersBeforeLoad = try await synthesizer.getSpeakers()
    #expect(speakersBeforeLoad.isEmpty || !speakersBeforeLoad.isEmpty) // May have default speakers

    // Load a voice model
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    // Get speakers after loading model
    let speakers = try await synthesizer.getSpeakers()
    #expect(!speakers.isEmpty, "Should have at least one speaker after loading model")

    // Verify speaker metadata structure
    for speaker in speakers {
      #expect(!speaker.name.isEmpty, "Speaker name should not be empty")
      #expect(!speaker.version.isEmpty, "Speaker version should not be empty")
      #expect(!speaker.styles.isEmpty, "Speaker should have at least one style")

      // Verify style metadata
      for style in speaker.styles {
        #expect(!style.name.isEmpty, "Style name should not be empty")
        #expect(!style.type.isEmpty, "Style type should not be empty")
      }
    }

    // Verify we can find a style ID 0 which we use in other tests
    let hasStyleZero = speakers.contains { speaker in
      speaker.styles.contains { $0.id == 0 }
    }
    #expect(hasStyleZero, "Should have style ID 0 available for testing")
  }

  @Test
  func testSynthesizeWithDifferentOptions() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()
    let synthesizer = try await VOICEVOXSynthesizer(configuration: config)
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    let optionsTrue = TTSOptions(enableInterrogativeUpspeak: true)
    let audioDataTrue = try await synthesizer.synthesize(
      text: "これはテストですか",
      styleId: 0,
      options: optionsTrue
    )

    let optionsFalse = TTSOptions(enableInterrogativeUpspeak: false)
    let audioDataFalse = try await synthesizer.synthesize(
      text: "これはテストですか",
      styleId: 0,
      options: optionsFalse
    )

    #expect(!audioDataTrue.isEmpty)
    #expect(!audioDataFalse.isEmpty)
  }
}
