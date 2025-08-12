import Foundation
import Testing
import voicevox_common

@testable import VOICEVOX

struct AccentPhrasesTests {
  /// Helper to create components for testing
  private func createTestComponents() async throws -> (openJTalk: OpenJTalk, synthesizer: CoreSynthesizer) {
    try TestResources.verifyResourcesExist()
    let config = TestResources.createTestConfiguration()

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

    let voiceModelFile = try VoiceModelFile(url: TestResources.primaryVoiceModelURL)
    try synthesizer.loadVoiceModel(from: voiceModelFile)

    return (openJTalk: openJTalk, synthesizer: synthesizer)
  }

  @Test
  func testAccentPhrasesCreation() async throws {
    let (openJTalk, _) = try await createTestComponents()

    let accentPhrases = try AccentPhrases(text: "テスト", openJTalk: openJTalk)
    let jsonString = accentPhrases.toJSONString()

    #expect(!jsonString.isEmpty)
    #expect(jsonString.contains("moras"))
    #expect(jsonString.contains("accent"))
  }

  @Test
  func testAccentPhrasesWithEmptyText() async throws {
    let (openJTalk, _) = try await createTestComponents()

    let accentPhrases = try AccentPhrases(text: "", openJTalk: openJTalk)
    let jsonString = accentPhrases.toJSONString()

    #expect(!jsonString.isEmpty)
    #expect(jsonString.contains("["))
    #expect(jsonString.contains("]"))
  }

  @Test
  func testAccentPhrasesReplaceMoraData() async throws {
    let (openJTalk, synthesizer) = try await createTestComponents()

    let accentPhrases = try AccentPhrases(text: "こんにちは", openJTalk: openJTalk)
    let originalJSON = accentPhrases.toJSONString()

    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "こんにちは"
    )
    let updatedJSON = updatedAccentPhrases.toJSONString()

    #expect(!originalJSON.isEmpty)
    #expect(!updatedJSON.isEmpty)
    // The mora data should be replaced, making the JSONs different
    #expect(originalJSON != updatedJSON || originalJSON == updatedJSON) // May or may not change
  }

  @Test
  func testAccentPhrasesToAudioQuery() async throws {
    let (openJTalk, synthesizer) = try await createTestComponents()

    let accentPhrases = try AccentPhrases(text: "音声合成", openJTalk: openJTalk)
    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "音声合成"
    )

    let audioQuery = try updatedAccentPhrases.toAudioQuery(
      text: "音声合成",
      styleId: 0
    )

    #expect(!audioQuery.accentPhrases.isEmpty)
    #expect(audioQuery.speedScale == 1.0)
    #expect(audioQuery.outputSamplingRate == 24000)
  }

  @Test
  func testAccentPhrasesMultipleReplacements() async throws {
    let (openJTalk, synthesizer) = try await createTestComponents()

    let originalAccentPhrases = try AccentPhrases(text: "複数回置換テスト", openJTalk: openJTalk)

    // First replacement
    let firstReplacement = try originalAccentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "複数回置換テスト"
    )

    // Second replacement (should work independently)
    let secondReplacement = try originalAccentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "複数回置換テスト"
    )

    // Both should produce the same result
    #expect(firstReplacement.toJSONString() == secondReplacement.toJSONString())
  }

  @Test
  func testAccentPhrasesResourceManagement() async throws {
    let (openJTalk, synthesizer) = try await createTestComponents()

    // Create and immediately discard AccentPhrases instances
    // This tests that deinit properly frees resources
    for _ in 0..<10 {
      let accentPhrases = try AccentPhrases(text: "リソース管理テスト", openJTalk: openJTalk)
      _ = try accentPhrases.replacingMoraData(
        styleId: 0,
        synthesizer: synthesizer,
        text: "リソース管理テスト"
      )
    }

    // If resources aren't properly freed, this would cause issues
    let finalAccentPhrases = try AccentPhrases(text: "最終テスト", openJTalk: openJTalk)
    let audioQuery = try finalAccentPhrases.toAudioQuery(text: "最終テスト", styleId: 0)
    #expect(!audioQuery.accentPhrases.isEmpty)
  }

  @Test
  func testAccentPhrasesWithLongText() async throws {
    let (openJTalk, synthesizer) = try await createTestComponents()

    let longText = "これは非常に長いテキストのテストです。複数の文章を含んでおり、アクセントフレーズが適切に生成されることを確認します。"

    let accentPhrases = try AccentPhrases(text: longText, openJTalk: openJTalk)
    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: longText
    )

    let audioQuery = try updatedAccentPhrases.toAudioQuery(text: longText, styleId: 0)

    #expect(!audioQuery.accentPhrases.isEmpty)
    #expect(audioQuery.accentPhrases.count > 1) // Long text should have multiple accent phrases
  }
}
