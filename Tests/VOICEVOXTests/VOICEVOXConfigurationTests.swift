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
    #expect(config.accelerationMode == .auto)
    #expect(config.cpuNumThreads == 0)
  }

  @Test
  func testCustomConfiguration() {
    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: URL(fileURLWithPath: "/custom/path"),
      accelerationMode: .gpu,
      cpuNumThreads: 4
    )

    #expect(config.openJTalkDictionaryURL == URL(fileURLWithPath: "/custom/path"))
    #expect(config.accelerationMode == .gpu)
    #expect(config.cpuNumThreads == 4)
  }

  @Test
  func testAccelerationModeValues() {
    #expect(VOICEVOXConfiguration.AccelerationMode.auto.rawValue == 0)
    #expect(VOICEVOXConfiguration.AccelerationMode.cpu.rawValue == 1)
    #expect(VOICEVOXConfiguration.AccelerationMode.gpu.rawValue == 2)
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
