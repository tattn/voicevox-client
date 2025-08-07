import Foundation

/// A Sendable wrapper for the synthesizer pointer.
///
/// This struct provides a thread-safe way to pass OpaquePointer across actor boundaries
/// while maintaining Swift concurrency safety requirements.
///
/// The struct is marked as @unchecked Sendable because OpaquePointer is inherently
/// thread-safe (it's just a memory address), but Swift doesn't mark it as Sendable.
struct SynthesizerPointer: @unchecked Sendable {
  /// The underlying pointer value.
  let value: OpaquePointer

  /// Creates a new synthesizer pointer wrapper.
  ///
  /// - Parameter pointer: The OpaquePointer to wrap.
  init(_ pointer: OpaquePointer) {
    self.value = pointer
  }
}
