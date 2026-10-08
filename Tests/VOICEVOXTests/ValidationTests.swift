import Foundation
import Testing

@testable import VOICEVOX

struct ValidationTests {
  private let validMora = AudioQuery.Mora(
    text: "テ",
    consonant: "t",
    consonantLength: 0.06,
    vowel: "e",
    vowelLength: 0.08,
    pitch: 5.5
  )

  private func makeAudioQuery(accentPhrases: [AudioQuery.AccentPhrase]) -> AudioQuery {
    AudioQuery(
      accentPhrases: accentPhrases,
      speedScale: 1.0,
      pitchScale: 0.0,
      intonationScale: 1.0,
      volumeScale: 1.0,
      prePhonemeLength: 0.1,
      postPhonemeLength: 0.1,
      outputSamplingRate: 24000,
      outputStereo: false,
      kana: nil
    )
  }

  @Test
  func testValidMora() throws {
    try validMora.validate()
  }

  @Test
  func testMoraWithConsonantButWithoutConsonantLength() {
    var mora = validMora
    mora.consonantLength = nil

    #expect {
      try mora.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .mora, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testMoraWithUnknownPhoneme() {
    var mora = validMora
    mora.vowel = "unknown"

    #expect(throws: VOICEVOXError.self) {
      try mora.validate()
    }
  }

  @Test
  func testValidAccentPhrase() throws {
    try AudioQuery.AccentPhrase(moras: [validMora], accent: 1).validate()
  }

  @Test
  func testAccentPhraseWithAccentOutOfRange() {
    let accentPhrase = AudioQuery.AccentPhrase(moras: [validMora], accent: 2)

    #expect {
      try accentPhrase.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .accentPhrase, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testValidAudioQuery() throws {
    try makeAudioQuery(accentPhrases: [AudioQuery.AccentPhrase(moras: [validMora], accent: 1)]).validate()
  }

  @Test
  func testAudioQueryWithInvalidAccentPhrase() {
    let audioQuery = makeAudioQuery(accentPhrases: [AudioQuery.AccentPhrase(moras: [validMora], accent: 2)])

    #expect {
      try audioQuery.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .audioQuery, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testValidScoreAndNotes() throws {
    let score = Score(notes: [
      .rest(frameLength: 15),
      Score.Note(key: 60, lyric: "ド", frameLength: 45),
      .rest(frameLength: 15),
    ])

    try score.validate()
    for note in score.notes {
      try note.validate()
    }
  }

  @Test
  func testNoteWithLyricButWithoutKey() {
    let note = Score.Note(key: nil, lyric: "ド", frameLength: 45)

    #expect {
      try note.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .note, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testNoteWithKeyOutOfRange() {
    #expect(throws: VOICEVOXError.self) {
      try Score.Note(key: 128, lyric: "ド", frameLength: 45).validate()
    }
  }

  @Test
  func testScoreStartingWithNote() {
    let score = Score(notes: [Score.Note(key: 60, lyric: "ド", frameLength: 45)])

    #expect {
      try score.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .score, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testEmptyScore() {
    #expect(throws: VOICEVOXError.self) {
      try Score(notes: []).validate()
    }
  }

  @Test
  func testFramePhonemeAndFrameAudioQuery() throws {
    let phoneme = FrameAudioQuery.FramePhoneme(phoneme: "pau", frameLength: 15)
    try phoneme.validate()

    let query = FrameAudioQuery(
      f0: Array(repeating: 0, count: 15),
      volume: Array(repeating: 0, count: 15),
      phonemes: [phoneme]
    )
    try query.validate()
  }

  @Test
  func testFramePhonemeWithUnknownPhoneme() {
    #expect {
      try FrameAudioQuery.FramePhoneme(phoneme: "unknown", frameLength: 15).validate()
    } throws: { error in
      guard case .invalidQuery(kind: .framePhoneme, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testFrameAudioQueryWithNegativeF0() {
    let query = FrameAudioQuery(
      f0: [-1],
      volume: [0],
      phonemes: [FrameAudioQuery.FramePhoneme(phoneme: "pau", frameLength: 1)]
    )

    #expect {
      try query.validate()
    } throws: { error in
      guard case .invalidQuery(kind: .frameAudioQuery, _) = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testEnsureCompatibleWithMismatchedPhonemes() {
    let score = Score(notes: [
      .rest(frameLength: 15),
      Score.Note(key: 60, lyric: "ド", frameLength: 45),
    ])
    let query = FrameAudioQuery(
      f0: Array(repeating: 0, count: 60),
      volume: Array(repeating: 0, count: 60),
      phonemes: [
        FrameAudioQuery.FramePhoneme(phoneme: "pau", frameLength: 15),
        FrameAudioQuery.FramePhoneme(phoneme: "r", frameLength: 5),
        FrameAudioQuery.FramePhoneme(phoneme: "e", frameLength: 40),
      ]
    )

    #expect {
      try query.ensureCompatible(with: score)
    } throws: { error in
      guard case .incompatibleQueries = error as? VOICEVOXError else { return false }
      return true
    }
  }

  @Test
  func testScoreJSONShape() throws {
    let score = Score(notes: [
      .rest(frameLength: 15),
      Score.Note(key: 60, lyric: "ド", frameLength: 45, id: "a"),
    ])

    let json = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(score)) as? [String: [[String: Any]]]
    )
    let notes = try #require(json["notes"])

    #expect(notes[0]["key"] == nil)
    #expect((notes[0]["lyric"] as? String)?.isEmpty == true)
    #expect(notes[0]["frame_length"] as? Int == 15)
    #expect(notes[1]["key"] as? Int == 60)
    #expect(notes[1]["id"] as? String == "a")
  }
}
