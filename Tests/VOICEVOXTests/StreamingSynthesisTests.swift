import Foundation
import Testing

@testable import VOICEVOX

struct StreamingSynthesisTests {
  /// 四国めたん（あまあま）, a `streaming_talk` style.
  private let styleId: UInt32 = 0
  private let text = "こんにちは、ストリーミングのテストです"
  private let wavHeaderLength = 44
  private let bytesPerSample = 2

  private func createSynthesizer() async throws -> Synthesizer {
    try TestResources.verifyResourcesExist()
    let synthesizer = try await Synthesizer(configuration: TestResources.createTestConfiguration())
    try await synthesizer.loadVoiceModel(from: TestResources.primaryVoiceModelURL)
    return synthesizer
  }

  /// The number of samples per frame at the default sampling rate of 24 kHz.
  private var samplesPerFrame: Int {
    Int(24_000 / AudioFeature.frameRate)
  }

  @Test
  func testStreamingTalkStyleType() throws {
    try TestResources.verifyResourcesExist()
    let styles = try Synthesizer.speakers(from: TestResources.primaryVoiceModelURL).flatMap(\.styles)

    #expect(styles.first { $0.id == styleId }?.styleType == .streamingTalk)
  }

  @Test
  func testCreateAudioFeature() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.makeAudioQuery(text: text, styleId: styleId)

    let audioFeature = try await synthesizer.createAudioFeature(audioQuery: query, styleId: styleId)

    #expect(audioFeature.frameLength > 0)
    #expect(audioFeature.samplingRate == query.outputSamplingRate)
    #expect(audioFeature.isStereo == query.outputStereo)
    #expect(audioFeature.duration == Double(audioFeature.frameLength) / AudioFeature.frameRate)
  }

  @Test
  func testRenderRanges() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.makeAudioQuery(text: text, styleId: styleId)
    let audioFeature = try await synthesizer.createAudioFeature(audioQuery: query, styleId: styleId)

    let pcm = try await synthesizer.render(audioFeature, frames: 0..<10)
    #expect(pcm.count == 10 * samplesPerFrame * bytesPerSample)

    let empty = try await synthesizer.render(audioFeature, frames: 5..<5)
    #expect(empty.isEmpty)

    await #expect(throws: VOICEVOXError.self) {
      try await synthesizer.render(audioFeature, frames: 0..<(audioFeature.frameLength + 1))
    }
  }

  @Test
  func testStreamingSynthesisMatchesSynthesis() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.makeAudioQuery(text: text, styleId: styleId)

    var segments: [Data] = []
    for try await segment in synthesizer.streamingSynthesis(audioQuery: query, styleId: styleId) {
      segments.append(segment)
    }
    let streamedPCM = segments.reduce(into: Data()) { $0.append($1) }
    let wav = try await synthesizer.synthesize(audioQuery: query, styleId: styleId)

    #expect(segments.count > 1)
    #expect(segments.dropLast().allSatisfy { $0.count == 28 * samplesPerFrame * bytesPerSample })
    #expect(streamedPCM.count == wav.count - wavHeaderLength)
  }

  @Test
  func testStreamingSynthesisWithUnknownStyleFails() async throws {
    let synthesizer = try await createSynthesizer()
    let query = try await synthesizer.makeAudioQuery(text: text, styleId: styleId)
    let unknownStyleId: UInt32 = 999_999

    await #expect(throws: VOICEVOXError.self) {
      for try await _ in synthesizer.streamingSynthesis(audioQuery: query, styleId: unknownStyleId) {}
    }
  }
}
