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
      "Synthesizer should throw VOICEVOXError when initialized with invalid dictionary path"
    ) {
      _ = try await Synthesizer(configuration: config)
    }
  }

  @Test
  func testLoadVoiceModelWithInvalidPath() async throws {
    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())

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

    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
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

    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
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

  @Test
  func testMakeAudioQuery() async throws {
    try TestResources.verifyResourcesExist()

    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
    let modelID = try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    // Create an audio query
    let audioQuery = try await synthesizer.makeAudioQuery(
      text: "テスト音声",
      styleId: 0
    )

    // Verify the audio query structure
    #expect(!audioQuery.accentPhrases.isEmpty, "AudioQuery should contain accent phrases")
    #expect(audioQuery.speedScale == 1.0, "Default speed scale should be 1.0")
    #expect(audioQuery.outputSamplingRate == 24000, "Default sampling rate should be 24000")

    try await synthesizer.unloadVoiceModel(modelID: modelID)
  }

  @Test
  func testSynthesizeWithAudioQuery() async throws {
    try TestResources.verifyResourcesExist()

    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
    let modelID = try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    // Step 1: Create an audio query
    let audioQuery = try await synthesizer.makeAudioQuery(
      text: "音声合成テスト",
      styleId: 0
    )

    // Step 2: Synthesize using the audio query
    let audioData = try await synthesizer.synthesize(
      audioQuery: audioQuery,
      styleId: 0
    )

    // Verify the audio data
    #expect(!audioData.isEmpty, "Generated audio data should not be empty")
    #expect(audioData.count > 44, "Audio data should be larger than WAV header")

    // Verify RIFF header for WAV format
    #expect(
      audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]),
      "Generated audio should have valid RIFF header indicating WAV format"
    )

    try await synthesizer.unloadVoiceModel(modelID: modelID)
  }

  @Test
  func testModifyAudioQueryBeforeSynthesis() async throws {
    try TestResources.verifyResourcesExist()

    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
    let modelID = try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)

    // Create an audio query
    let audioQuery = try await synthesizer.makeAudioQuery(
      text: "速度変更テスト",
      styleId: 0
    )

    // Modify the audio query parameters
    let modifiedQuery = AudioQuery(
      accentPhrases: audioQuery.accentPhrases,
      speedScale: 1.5, // Speed up the speech
      pitchScale: audioQuery.pitchScale,
      intonationScale: audioQuery.intonationScale,
      volumeScale: audioQuery.volumeScale,
      prePhonemeLength: audioQuery.prePhonemeLength,
      postPhonemeLength: audioQuery.postPhonemeLength,
      outputSamplingRate: audioQuery.outputSamplingRate,
      outputStereo: audioQuery.outputStereo,
      kana: audioQuery.kana
    )

    // Synthesize with modified query
    let audioData = try await synthesizer.synthesize(
      audioQuery: modifiedQuery,
      styleId: 0
    )

    #expect(!audioData.isEmpty, "Generated audio data should not be empty")

    try await synthesizer.unloadVoiceModel(modelID: modelID)
  }
}
