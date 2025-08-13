import Foundation
import Testing
import voicevox_common

@testable import VOICEVOX

struct CoreSynthesizerTests {
  /// Helper to create a configured synthesizer for testing
  private func createSynthesizer() async throws -> CoreSynthesizer {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()

    // Initialize base components
    #if os(iOS)
    let onnxruntime = try OnnxRuntime()
    #else
    let onnxruntime = try OnnxRuntime(url: config.onnxruntimeDirectoryURL)
    #endif

    let openJTalk = try OpenJTalk(dictionaryURL: config.openJTalkDictionaryURL)
    let synthesizer = try CoreSynthesizer(
      onnxruntime: onnxruntime,
      openJTalk: openJTalk,
      configuration: config
    )

    // Load voice model
    let voiceModelFile = try VoiceModelFile(url: TestResources.primaryVoiceModelURL)
    try synthesizer.loadVoiceModel(from: voiceModelFile)

    return synthesizer
  }

  @Test
  func testAnalyze() async throws {
    let synthesizer = try await createSynthesizer()

    let accentPhrases = try synthesizer.analyze(text: "テスト")
    let jsonString = accentPhrases.toJSONString()

    #expect(!jsonString.isEmpty)
    #expect(jsonString.contains("moras"))
    #expect(jsonString.contains("accent"))
  }

  @Test
  func testMakeAudioQuery() async throws {
    let synthesizer = try await createSynthesizer()

    let audioQuery = try synthesizer.makeAudioQuery(text: "テスト", styleId: 0)

    #expect(!audioQuery.accentPhrases.isEmpty)
    #expect(audioQuery.speedScale == 1.0)
    #expect(audioQuery.outputSamplingRate == 24000)
  }

  @Test
  func testSynthesizeWithAudioQuery() async throws {
    let synthesizer = try await createSynthesizer()

    let audioQuery = try synthesizer.makeAudioQuery(text: "テスト", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData.count > 44) // WAV header is at least 44 bytes
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
  }

  @Test
  func testBasicSynthesis() async throws {
    let synthesizer = try await createSynthesizer()

    let audioQuery = try synthesizer.makeAudioQuery(text: "テスト", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData.count > 44) // WAV header is at least 44 bytes

    // Verify WAV header
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
    #expect(audioData[8...11] == Data([0x57, 0x41, 0x56, 0x45])) // "WAVE"
  }

  @Test
  func testSynthesisWithEmptyText() async throws {
    let synthesizer = try await createSynthesizer()

    let audioQuery = try synthesizer.makeAudioQuery(text: "", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty, "Should produce audio even for empty text")
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]))
  }

  @Test
  func testSynthesisWithLongText() async throws {
    let synthesizer = try await createSynthesizer()

    let longText = "これは長いテキストのテストです。複数の文章を含んでおり、正しく音声合成できることを確認します。"

    let audioQuery = try synthesizer.makeAudioQuery(text: longText, styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData.count > 1000, "Long text should produce larger audio data")
  }

  @Test
  func testSynthesisWithCustomOptions() async throws {
    let synthesizer = try await createSynthesizer()

    var options = voicevox_make_default_synthesis_options()
    options.enable_interrogative_upspeak = true

    let audioQuery = try synthesizer.makeAudioQuery(text: "これは質問ですか", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0, options: options)

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]))
  }

  @Test
  func testMultipleSynthesisCalls() async throws {
    let synthesizer = try await createSynthesizer()

    let audioQuery1 = try synthesizer.makeAudioQuery(text: "最初のテスト", styleId: 0)
    let audioData1 = try synthesizer.synthesize(audioQuery: audioQuery1, styleId: 0)

    let audioQuery2 = try synthesizer.makeAudioQuery(text: "二回目のテスト", styleId: 0)
    let audioData2 = try synthesizer.synthesize(audioQuery: audioQuery2, styleId: 0)

    let audioQuery3 = try synthesizer.makeAudioQuery(text: "三回目のテスト", styleId: 0)
    let audioData3 = try synthesizer.synthesize(audioQuery: audioQuery3, styleId: 0)

    #expect(!audioData1.isEmpty)
    #expect(!audioData2.isEmpty)
    #expect(!audioData3.isEmpty)

    // Different texts should produce different audio
    #expect(audioData1 != audioData2)
    #expect(audioData2 != audioData3)
  }

  @Test
  func testSynthesisConsistency() async throws {
    let synthesizer = try await createSynthesizer()

    let text = "同じテキスト"
    let options = voicevox_make_default_synthesis_options()

    let audioQuery1 = try synthesizer.makeAudioQuery(text: text, styleId: 0)
    let audioData1 = try synthesizer.synthesize(audioQuery: audioQuery1, styleId: 0, options: options)

    let audioQuery2 = try synthesizer.makeAudioQuery(text: text, styleId: 0)
    let audioData2 = try synthesizer.synthesize(audioQuery: audioQuery2, styleId: 0, options: options)

    // Same text with same parameters should produce identical results
    #expect(audioData1 == audioData2)
  }

  @Test
  func testSynthesisWithNumbers() async throws {
    let synthesizer = try await createSynthesizer()

    let textWithNumbers = "今日は2024年12月8日です。"

    let audioQuery = try synthesizer.makeAudioQuery(text: textWithNumbers, styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]))
  }

  @Test
  func testSynthesisWithEnglishMixed() async throws {
    let synthesizer = try await createSynthesizer()

    let mixedText = "VOICEVOXはText to Speechエンジンです。"

    let audioQuery = try synthesizer.makeAudioQuery(text: mixedText, styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]))
  }

  @Test
  func testSynthesisPerformance() async throws {
    let synthesizer = try await createSynthesizer()

    let startTime = Date()

    let audioQuery = try synthesizer.makeAudioQuery(text: "パフォーマンステスト", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    let elapsedTime = Date().timeIntervalSince(startTime)

    #expect(!audioData.isEmpty)
    #expect(elapsedTime < 10.0, "Synthesis should complete within 10 seconds")

    print("Synthesis completed in \(String(format: "%.3f", elapsedTime)) seconds")
  }

  @Test
  func testInvalidStyleId() async throws {
    let synthesizer = try await createSynthesizer()

    // Using an invalid style ID should throw an error
    #expect(throws: VOICEVOXError.self) {
      let audioQuery = try synthesizer.makeAudioQuery(
        text: "テスト",
        styleId: 99999 // Invalid style ID
      )
      _ = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 99999)
    }
  }

  @Test
  func testAnalyzeAndSynthesizeSeparately() async throws {
    let synthesizer = try await createSynthesizer()

    // Step 1: Analyze text
    let accentPhrases = try synthesizer.analyze(text: "分離テスト")

    // Step 2: Replace mora data
    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "分離テスト"
    )

    // Step 3: Create audio query
    let audioQuery = try updatedAccentPhrases.toAudioQuery(
      text: "分離テスト",
      styleId: 0
    )

    // Step 4: Synthesize
    let audioData = try synthesizer.synthesize(
      audioQuery: audioQuery,
      styleId: 0
    )

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46]))
  }

  @Test
  func testReplaceMoraData() async throws {
    let synthesizer = try await createSynthesizer()

    // Create an initial audio query
    let originalAudioQuery = try synthesizer.makeAudioQuery(text: "ピッチリセットテスト", styleId: 0)

    // Store original pitch values for comparison
    let originalPitches = originalAudioQuery.accentPhrases.flatMap { phrase in
      phrase.moras.map(\.pitch)
    }

    // Replace mora data with the same style ID (should reset pitches)
    let updatedAudioQuery = try synthesizer.replaceMoraData(
      audioQuery: originalAudioQuery,
      styleId: 0
    )

    // Verify that the audio query structure is preserved
    #expect(updatedAudioQuery.accentPhrases.count == originalAudioQuery.accentPhrases.count)
    #expect(updatedAudioQuery.speedScale == originalAudioQuery.speedScale)
    #expect(updatedAudioQuery.pitchScale == originalAudioQuery.pitchScale)
    #expect(updatedAudioQuery.intonationScale == originalAudioQuery.intonationScale)
    #expect(updatedAudioQuery.volumeScale == originalAudioQuery.volumeScale)
    #expect(updatedAudioQuery.outputSamplingRate == originalAudioQuery.outputSamplingRate)

    // Verify that accent phrases have the same structure
    for (original, updated) in zip(originalAudioQuery.accentPhrases, updatedAudioQuery.accentPhrases) {
      #expect(original.moras.count == updated.moras.count)
      #expect(original.accent == updated.accent)
      #expect(original.isInterrogative == updated.isInterrogative)
    }

    // The pitch values should have been recalculated
    let updatedPitches = updatedAudioQuery.accentPhrases.flatMap { phrase in
      phrase.moras.map(\.pitch)
    }

    // Since we're using the same style ID, the pitches should be identical
    // (deterministic for the same text and style)
    #expect(originalPitches == updatedPitches)
  }

  @Test
  func testReplaceMoraDataWithModifiedAudioQuery() async throws {
    let synthesizer = try await createSynthesizer()

    // Create an initial audio query
    var audioQuery = try synthesizer.makeAudioQuery(text: "変更テスト", styleId: 0)

    // Modify some parameters
    audioQuery.speedScale = 1.5
    audioQuery.pitchScale = 0.8
    audioQuery.volumeScale = 1.2

    // Replace mora data
    let updatedAudioQuery = try synthesizer.replaceMoraData(
      audioQuery: audioQuery,
      styleId: 0
    )

    // Verify that the modified parameters are preserved
    #expect(updatedAudioQuery.speedScale == 1.5)
    #expect(updatedAudioQuery.pitchScale == 0.8)
    #expect(updatedAudioQuery.volumeScale == 1.2)

    // The accent phrases should have been updated
    #expect(!updatedAudioQuery.accentPhrases.isEmpty)
  }

  @Test
  func testReplaceMoraDataAndSynthesize() async throws {
    let synthesizer = try await createSynthesizer()

    // Create an audio query
    let audioQuery = try synthesizer.makeAudioQuery(text: "合成テスト", styleId: 0)

    // Replace mora data
    let updatedAudioQuery = try synthesizer.replaceMoraData(
      audioQuery: audioQuery,
      styleId: 0
    )

    // Synthesize audio with the updated query
    let audioData = try synthesizer.synthesize(
      audioQuery: updatedAudioQuery,
      styleId: 0
    )

    #expect(!audioData.isEmpty)
    #expect(audioData.count > 44) // WAV header is at least 44 bytes
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
  }
}
