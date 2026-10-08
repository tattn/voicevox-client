import Foundation
import Testing

@testable import VOICEVOX

struct URLFileSystemPathTests {
  @Test
  func testFileSystemPathIsNotPercentEncoded() {
    let url = URL(filePath: "/tmp/voice models/四国めたん.vvm")

    #expect(url.fileSystemPath == "/tmp/voice models/四国めたん.vvm")
  }

  @Test
  func testFileSystemPathResolvesRelativeURL() throws {
    let url = URL(filePath: "lib/0.vvm", relativeTo: URL(filePath: "/tmp/resources/", directoryHint: .isDirectory))
    try #require(url.baseURL != nil)

    #expect(url.fileSystemPath == "/tmp/resources/lib/0.vvm")
  }
}
