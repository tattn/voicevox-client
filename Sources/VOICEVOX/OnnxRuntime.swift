import Foundation
import voicevox_common

/// Wrapper for OnnxRuntime.
final class OnnxRuntime {
  let pointer: OpaquePointer

  #if os(iOS)
  init() throws(VOICEVOXError) {
    var onnxruntime = voicevox_onnxruntime_get()
    let resultCode = voicevox_onnxruntime_init_once(&onnxruntime)

    guard resultCode == 0, let onnxruntime else {
      throw .initializationFailed(
        message: "OnnxRuntime initialization failed",
        underlyingErrorCode: Int(resultCode)
      )
    }

    self.pointer = onnxruntime
  }
  #else
  init(url: URL) throws(VOICEVOXError) {
    var onnxruntime = voicevox_onnxruntime_get()
    let libURL = Self.libraryURL(in: url)
    let resultCode = libURL.fileSystemPath
      .withCString { filename in
        var loadOptions = voicevox_make_default_load_onnxruntime_options()
        loadOptions.filename = filename
        return voicevox_onnxruntime_load_once(loadOptions, &onnxruntime)
      }

    guard resultCode == 0, let onnxruntime else {
      throw .initializationFailed(
        message: "OnnxRuntime initialization failed (\(libURL.lastPathComponent))",
        underlyingErrorCode: Int(resultCode)
      )
    }

    self.pointer = onnxruntime
  }

  /// Returns the URL of the ONNX Runtime dynamic library in the given directory.
  ///
  /// VOICEVOX Core accepts a range of ONNX Runtime versions (e.g. 1.17.3 still works although 1.23.2 is
  /// recommended), so the newest library satisfying the minimum required minor version is used when the
  /// recommended one is absent.
  static func libraryURL(in directory: URL) -> URL {
    let recommendedFileName = String(cString: voicevox_get_onnxruntime_lib_recommended_versioned_filename())
    let recommendedURL = directory.appending(path: recommendedFileName)
    guard !FileManager.default.fileExists(atPath: recommendedURL.fileSystemPath) else {
      return recommendedURL
    }

    let minimumMinorVersion = Int(voicevox_get_onnxruntime_lib_min_required_minor_version())
    let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: directory.fileSystemPath)) ?? []
    let newestCompatibleLibrary =
      fileNames
      .compactMap(VersionedLibrary.init(fileName:))
      .filter { $0.isCompatible(minimumMinorVersion: minimumMinorVersion) }
      .max { $0.version.lexicographicallyPrecedes($1.version) }

    return newestCompatibleLibrary.map { directory.appending(path: $0.fileName) } ?? recommendedURL
  }

  /// An ONNX Runtime library file name such as `libvoicevox_onnxruntime.1.17.3.dylib`.
  private struct VersionedLibrary {
    let fileName: String
    let version: [Int]

    init?(fileName: String) {
      let unversionedFileName = String(cString: voicevox_get_onnxruntime_lib_recommended_unversioned_filename())
      let fileExtension = ".dylib"
      guard unversionedFileName.hasSuffix(fileExtension), fileName.hasSuffix(fileExtension) else {
        return nil
      }

      let prefix = unversionedFileName.dropLast(fileExtension.count) + "."
      guard fileName.hasPrefix(prefix) else {
        return nil
      }

      let components = fileName.dropFirst(prefix.count).dropLast(fileExtension.count).split(separator: ".")
      let version = components.compactMap { Int($0) }
      guard !version.isEmpty, version.count == components.count else {
        return nil
      }

      self.fileName = fileName
      self.version = version
    }

    func isCompatible(minimumMinorVersion: Int) -> Bool {
      version.count >= 2 && version[0] == 1 && version[1] >= minimumMinorVersion
    }
  }
  #endif
}
