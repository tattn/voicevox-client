import Foundation
import Testing

@testable import VOICEVOX

struct SpeakerTests {
  @Test(
    arguments: [
      ("talk", Speaker.StyleType.talk),
      ("singing_teacher", .singingTeacher),
      ("frame_decode", .frameDecode),
      ("sing", .sing),
      ("streaming_talk", .streamingTalk),
    ]
  )
  func testStyleType(rawType: String, expected: Speaker.StyleType) throws {
    let json = #"{"id": 1, "name": "ノーマル", "order": 0, "type": "\#(rawType)"}"#
    let style = try JSONDecoder().decode(Speaker.Style.self, from: Data(json.utf8))

    #expect(style.type == rawType)
    #expect(style.styleType == expected)
  }

  @Test
  func testUnknownStyleType() throws {
    let json = #"{"id": 1, "name": "ノーマル", "order": 0, "type": "future_type"}"#
    let style = try JSONDecoder().decode(Speaker.Style.self, from: Data(json.utf8))

    #expect(style.styleType == nil)
  }
}
