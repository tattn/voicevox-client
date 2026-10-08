#if os(macOS)
import Foundation
import Testing

@testable import VOICEVOX

struct OnnxRuntimeTests {
  @Test
  func testLibraryURLFallsBackToCompatibleLibrary() {
    let libraryURL = OnnxRuntime.libraryURL(in: TestResources.libURL)

    #expect(libraryURL.lastPathComponent == "libvoicevox_onnxruntime.1.17.3.dylib")
  }
}
#endif
