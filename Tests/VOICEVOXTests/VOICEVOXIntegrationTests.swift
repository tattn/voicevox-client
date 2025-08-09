import Foundation
import Testing
import voicevox_common

@testable import VOICEVOX

struct VOICEVOXIntegrationTests {
  @Test
  func testInitializationWithInvalidPath() async throws {
    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(fileURLWithPath: "/invalid/path")
    )

    await #expect(
      throws: VOICEVOXError.self,
      "VOICEVOXSynthesizer should throw VOICEVOXError when initialized with invalid dictionary path"
    ) {
      _ = try await VOICEVOXSynthesizer(configuration: config)
    }
  }

  @Test
  func testLoadVoiceModelWithInvalidPath() async throws {
    let synthesizer = try await VOICEVOXSynthesizer(configuration: TestResources.createTestConfiguration())

    await #expect(
      throws: VOICEVOXError.self,
      "Loading voice model should throw VOICEVOXError when given invalid model path"
    ) {
      try await synthesizer.loadVoiceModel(from: URL(fileURLWithPath: "/invalid/model.vvm"))
    }
  }

  @Test
  func testFullWorkflow() async throws {
    try TestResources.verifyResourcesExist()

    let synthesizer = try await VOICEVOXSynthesizer(configuration: TestResources.createTestConfiguration())
    let modelID = try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    let audioData = try await synthesizer.synthesize(
      text: "こんにちは",
      styleId: 0,
      options: .standard
    )

    #expect(!audioData.isEmpty, "Generated audio data should not be empty")

    // Verify RIFF header for WAV format
    #expect(
      audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]),
      "Generated audio should have valid RIFF header indicating WAV format"
    )

    try await synthesizer.unloadVoiceModel(modelID: modelID)
  }

  @Test
  func testMultipleVoiceModelsLoading() async throws {
    try TestResources.verifyResourcesExist()

    let voiceModelURLs = [
      TestResources.voiceModelURL(id: 0),
      TestResources.voiceModelURL(id: 1),
    ]

    // Verify all voice models exist before testing
    for index in voiceModelURLs.indices {
      try TestResources.verifyVoiceModelExists(id: index)
    }

    let synthesizer = try await VOICEVOXSynthesizer(configuration: TestResources.createTestConfiguration())
    var modelIDs: [VoiceModelID] = []
    for model in voiceModelURLs {
      let modelID = try await synthesizer.loadVoiceModel(from: model)
      modelIDs.append(modelID)
    }

    // Clean up by unloading all models
    for modelID in modelIDs {
      try await synthesizer.unloadVoiceModel(modelID: modelID)
    }
  }
}
