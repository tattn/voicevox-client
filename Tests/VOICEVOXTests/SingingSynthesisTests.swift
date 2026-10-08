import Foundation
import Testing

@testable import VOICEVOX

struct SingingSynthesisTests {
  /// 波音リツ（ノーマル）, a `sing` style that can both create frame audio queries and synthesize.
  private let singerStyleId: UInt32 = 6000
  /// 四国めたん（あまあま）, a `frame_decode` style.
  private let frameDecodeStyleId: UInt32 = 3000

  private let score = Score(notes: [
    .rest(frameLength: 15),
    Score.Note(key: 60, lyric: "ド", frameLength: 45, id: "do"),
    Score.Note(key: 62, lyric: "レ", frameLength: 45),
    Score.Note(key: 64, lyric: "ミ", frameLength: 45),
    .rest(frameLength: 15),
  ])

  private func createSynthesizer() async throws -> Synthesizer {
    try TestResources.verifySongVoiceModelExists()
    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
    try await synthesizer.loadVoiceModel(from: TestResources.songVoiceModelURL)
    return synthesizer
  }

  @Test
  func testSongStyleTypes() throws {
    try TestResources.verifySongVoiceModelExists()
    let styles = try Synthesizer.speakers(from: TestResources.songVoiceModelURL).flatMap(\.styles)

    #expect(styles.first { $0.id == singerStyleId }?.styleType == .sing)
    #expect(styles.first { $0.id == frameDecodeStyleId }?.styleType == .frameDecode)
  }

  @Test
  func testCreateSingFrameAudioQuery() async throws {
    let synthesizer = try await createSynthesizer()

    let query = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: singerStyleId)

    let totalFrameLength = score.notes.map(\.frameLength).reduce(0, +)
    #expect(query.f0.count == totalFrameLength)
    #expect(query.volume.count == totalFrameLength)
    #expect(query.phonemes.map(\.phoneme) == ["pau", "d", "o", "r", "e", "m", "i", "pau"])
    #expect(query.phonemes.map(\.frameLength).reduce(0, +) == totalFrameLength)
    #expect(query.phonemes.filter { $0.noteId == "do" }.map(\.phoneme) == ["d", "o"])
    #expect(query.outputSamplingRate == 24000)
    try query.validate()
    try query.ensureCompatible(with: score)
  }

  @Test
  func testCreateSingFrameF0AndVolume() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: singerStyleId)

    let f0 = try await synthesizer.createSingFrameF0(score: score, frameAudioQuery: query, styleId: singerStyleId)
    let volume = try await synthesizer.createSingFrameVolume(
      score: score,
      frameAudioQuery: query,
      styleId: singerStyleId
    )

    #expect(f0.count == query.f0.count)
    #expect(volume.count == query.volume.count)
    #expect(f0.contains { $0 > 0 })
  }

  @Test
  func testFrameSynthesis() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: singerStyleId)

    for styleId in [singerStyleId, frameDecodeStyleId] {
      let audioData = try await synthesizer.synthesize(frameAudioQuery: query, styleId: styleId)

      #expect(audioData.count > 44)
      #expect(audioData[0...3] == Data([0x52, 0x49, 0x46, 0x46])) // "RIFF"
      #expect(audioData[8...11] == Data([0x57, 0x41, 0x56, 0x45])) // "WAVE"
    }
  }

  @Test
  func testCreateSingFrameAudioQueryWithInvalidScore() async throws {
    let synthesizer = try await createSynthesizer()
    let invalidScore = Score(notes: [Score.Note(key: 60, lyric: "ド", frameLength: 45)])

    await #expect {
      _ = try await synthesizer.createSingFrameAudioQuery(score: invalidScore, styleId: singerStyleId)
    } throws: { error in
      guard case .invalidQuery(kind: .score, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testCreateSingFrameF0WithIncompatibleQuery() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: singerStyleId)
    var otherScore = score
    otherScore.notes[1].lyric = "ラ"

    await #expect {
      _ = try await synthesizer.createSingFrameF0(score: otherScore, frameAudioQuery: query, styleId: singerStyleId)
    } throws: { error in
      guard case .incompatibleQueries = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testFrameSynthesisWithTalkStyleFails() async throws {
    let synthesizer = try await createSynthesizer()
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)
    let query = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: singerStyleId)

    await #expect(throws: VOICEVOXError.self) {
      _ = try await synthesizer.synthesize(frameAudioQuery: query, styleId: 0)
    }
  }
}
