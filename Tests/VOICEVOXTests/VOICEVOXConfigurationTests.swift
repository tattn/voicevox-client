import Foundation
import Testing

@testable import VOICEVOX

struct VOICEVOXConfigurationTests {
  @Test
  func testDefaultConfiguration() {
    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(fileURLWithPath: "/path/to/dict")
    )

    #expect(config.openJTalkDictionaryURL == URL(fileURLWithPath: "/path/to/dict"))
    #expect(config.cpuNumThreads == 0)
  }

  @Test
  func testCustomConfiguration() {
    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(fileURLWithPath: "/custom/path"),
      cpuNumThreads: 4
    )

    #expect(config.openJTalkDictionaryURL == URL(fileURLWithPath: "/custom/path"))
    #expect(config.cpuNumThreads == 4)
  }

  @Test
  func testTTSOptionsDefault() {
    let options = TTSOptions()
    #expect(options.enableInterrogativeUpspeak == true)
  }

  @Test
  func testTTSOptionsCustom() {
    let options = TTSOptions(enableInterrogativeUpspeak: false)
    #expect(options.enableInterrogativeUpspeak == false)
  }
}
