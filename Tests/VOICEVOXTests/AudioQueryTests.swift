import Foundation
import Testing
import voicevox_common

@testable import VOICEVOX

struct AudioQueryTests {
  /// Test JSON provided by the user
  private let testJSON = """
    {
      "accent_phrases": [
        {
          "moras": [
            {
              "text": "テ",
              "consonant": "t",
              "consonant_length": 0.061567612,
              "vowel": "e",
              "vowel_length": 0.083977446,
              "pitch": 0.0
            },
            {
              "text": "ス",
              "consonant": "s",
              "consonant_length": 0.050780214,
              "vowel": "U",
              "vowel_length": 0.07213184,
              "pitch": 0.0
            },
            {
              "text": "ト",
              "consonant": "t",
              "consonant_length": 0.072674334,
              "vowel": "o",
              "vowel_length": 0.14846806,
              "pitch": 0.0
            }
          ],
          "accent": 1,
          "pause_mora": null,
          "is_interrogative": false
        }
      ],
      "speedScale": 1.0,
      "pitchScale": 0.0,
      "intonationScale": 1.0,
      "volumeScale": 1.0,
      "prePhonemeLength": 0.1,
      "postPhonemeLength": 0.1,
      "outputSamplingRate": 24000,
      "outputStereo": false,
      "kana": "テ'_スト"
    }
    """

  @Test
  func testAudioQueryDecoding() throws {
    let jsonData = testJSON.data(using: .utf8)!
    let audioQuery = try AudioQuery(from: jsonData)

    // Verify top-level properties
    #expect(audioQuery.speedScale == 1.0)
    #expect(audioQuery.pitchScale == 0.0)
    #expect(audioQuery.intonationScale == 1.0)
    #expect(audioQuery.volumeScale == 1.0)
    #expect(audioQuery.prePhonemeLength == 0.1)
    #expect(audioQuery.postPhonemeLength == 0.1)
    #expect(audioQuery.outputSamplingRate == 24000)
    #expect(audioQuery.outputStereo == false)
    #expect(audioQuery.kana == "テ'_スト")

    // Verify accent phrases
    #expect(audioQuery.accentPhrases.count == 1)
    let accentPhrase = audioQuery.accentPhrases[0]
    #expect(accentPhrase.accent == 1)
    #expect(accentPhrase.isInterrogative == false)
    #expect(accentPhrase.pauseMora == nil)

    // Verify moras
    #expect(accentPhrase.moras.count == 3)

    let mora1 = accentPhrase.moras[0]
    #expect(mora1.text == "テ")
    #expect(mora1.consonant == "t")
    #expect(mora1.vowel == "e")
    #expect(mora1.pitch == 0.0)

    let mora2 = accentPhrase.moras[1]
    #expect(mora2.text == "ス")
    #expect(mora2.consonant == "s")
    #expect(mora2.vowel == "U")

    let mora3 = accentPhrase.moras[2]
    #expect(mora3.text == "ト")
    #expect(mora3.consonant == "t")
    #expect(mora3.vowel == "o")
  }

  @Test
  func testAudioQueryRoundTrip() throws {
    let jsonData = testJSON.data(using: .utf8)!
    let audioQuery = try AudioQuery(from: jsonData)

    // Convert back to JSON
    let encodedData = try audioQuery.toJSONData()
    let encodedString = try audioQuery.toJSONString()

    #expect(!encodedData.isEmpty)
    #expect(!encodedString.isEmpty)

    // Decode again and verify
    let decodedQuery = try AudioQuery(from: encodedData)
    #expect(decodedQuery.speedScale == audioQuery.speedScale)
    #expect(decodedQuery.kana == audioQuery.kana)
    #expect(decodedQuery.accentPhrases.count == audioQuery.accentPhrases.count)
  }

  @Test
  func testSynthesizerCoreWithAudioQuery() async throws {
    try TestResources.verifyResourcesExist()

    let config = TestResources.createTestConfiguration()

    // Initialize components
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

    // Test the full flow with AudioQuery
    let audioQuery = try synthesizer.makeAudioQuery(text: "テスト", styleId: 0)
    let audioData = try synthesizer.synthesize(audioQuery: audioQuery, styleId: 0)

    #expect(!audioData.isEmpty)
    #expect(audioData.count > 44) // WAV header is at least 44 bytes
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
  }

  @Test
  func testCreateAudioQueryDirectly() async throws {
    try TestResources.verifyResourcesExist()
    let config = TestResources.createTestConfiguration()

    // Initialize components
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

    // Test creating AudioQuery from processed accent phrases
    let audioQuery = try await createTestAudioQuery(
      openJTalk: openJTalk,
      synthesizer: synthesizer
    )

    // Verify AudioQuery structure
    #expect(!audioQuery.accentPhrases.isEmpty)
    #expect(audioQuery.speedScale == 1.0)
    #expect(audioQuery.outputSamplingRate == 24000)

    // Synthesize using the AudioQuery
    let audioData = try synthesizer.synthesize(
      audioQuery: audioQuery,
      styleId: 0,
      options: voicevox_make_default_synthesis_options()
    )

    #expect(!audioData.isEmpty)
    #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
  }

  private func createTestAudioQuery(
    openJTalk: OpenJTalk,
    synthesizer: CoreSynthesizer
  ) async throws -> AudioQuery {
    // Create accent phrases using the new type
    let accentPhrases = try AccentPhrases(text: "テスト", openJTalk: openJTalk)

    // Replace mora data
    let updatedAccentPhrases = try accentPhrases.replacingMoraData(
      styleId: 0,
      synthesizer: synthesizer,
      text: "テスト"
    )

    // Convert to AudioQuery
    return try updatedAccentPhrases.toAudioQuery(
      text: "テスト",
      styleId: 0
    )
  }
}
