import Foundation

extension URL {
  /// The absolute, non-percent-encoded path for file system APIs such as `FileManager` and the VOICEVOX Core C API.
  ///
  /// `path()` percent-encodes characters such as spaces and non-ASCII letters, and does not resolve a relative URL
  /// (e.g. one derived from `Bundle.resourceURL`) against its base on older OS versions.
  package var fileSystemPath: String {
    absoluteURL.path(percentEncoded: false)
  }
}
