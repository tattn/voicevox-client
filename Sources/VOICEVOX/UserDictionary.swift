import Foundation
import os
import voicevox_common

private struct JSONWord: Decodable {
  let surface: String
  let priority: UInt32
  let contextId: Int
  let partOfSpeech: String
  let partOfSpeechDetail1: String
  let partOfSpeechDetail2: String
  let partOfSpeechDetail3: String
  let inflectionalType: String
  let inflectionalForm: String
  let stem: String
  let yomi: String
  let pronunciation: String
  let accentType: Int
  let moraCount: Int
  let accentAssociativeRule: String

  enum CodingKeys: String, CodingKey {
    case surface
    case priority
    case contextId = "context_id"
    case partOfSpeech = "part_of_speech"
    case partOfSpeechDetail1 = "part_of_speech_detail_1"
    case partOfSpeechDetail2 = "part_of_speech_detail_2"
    case partOfSpeechDetail3 = "part_of_speech_detail_3"
    case inflectionalType = "inflectional_type"
    case inflectionalForm = "inflectional_form"
    case stem
    case yomi
    case pronunciation
    case accentType = "accent_type"
    case moraCount = "mora_count"
    case accentAssociativeRule = "accent_associative_rule"
  }
}

/// User dictionary
public final class UserDictionary: @unchecked Sendable {
  /// Word types that can be registered in the user dictionary
  public enum WordType: Int32, CaseIterable, Sendable, Identifiable, Equatable, Hashable {
    /// Proper noun
    case properNoun = 0
    /// Common noun
    case commonNoun = 1
    /// Verb
    case verb = 2
    /// Adjective
    case adjective = 3
    /// Suffix
    case suffix = 4

    public var id: Self {
      self
    }

    var cValue: Int32 {
      rawValue
    }
  }

  /// Word to be registered in the user dictionary
  public struct Word: Sendable, Identifiable, Equatable, Hashable {
    /// Unique identifier
    public var id: UUID
    /// Surface form (kanji, hiragana, katakana, alphanumeric, etc.)
    public var surface: String
    /// Pronunciation (katakana)
    public var pronunciation: String
    /// Accent type (integer >= 1)
    public var accentType: Int
    /// Word type
    public var wordType: WordType
    /// Priority (integer >= 1, default 5)
    public var priority: UInt32

    /// Creates a new word
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - surface: Surface form
    ///   - pronunciation: Pronunciation (katakana)
    ///   - accentType: Accent type (>= 1)
    ///   - wordType: Word type (default: proper noun)
    ///   - priority: Priority (>= 1, default 5)
    public init(
      id: UUID = UUID(),
      surface: String,
      pronunciation: String,
      accentType: Int,
      wordType: WordType = .properNoun,
      priority: UInt32 = 5
    ) {
      self.id = id
      self.surface = surface
      self.pronunciation = pronunciation
      self.accentType = accentType
      self.wordType = wordType
      self.priority = priority
    }

    /// Converts to C API struct
    func toCStruct() -> VoicevoxUserDictWord {
      VoicevoxUserDictWord(
        surface: surface.withCString { strdup($0) },
        pronunciation: pronunciation.withCString { strdup($0) },
        accent_type: UInt(accentType),
        word_type: Int32(wordType.cValue),
        priority: priority
      )
    }
  }

  private let pointer: OpaquePointer
  private let lock = OSAllocatedUnfairLock()

  /// Creates a new user dictionary
  public init() {
    pointer = voicevox_user_dict_new()
  }

  deinit {
    voicevox_user_dict_delete(pointer)
  }

  /// Adds a word to the dictionary
  /// - Parameter word: Word to add
  /// - Returns: UUID of the added word
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func addWord(_ word: Word) throws(VOICEVOXError) -> UUID {
    try performLocked {
      var uuidBytes = [UInt8](repeating: 0, count: 16)
      var cWord = word.toCStruct()
      defer {
        free(UnsafeMutablePointer(mutating: cWord.surface))
        free(UnsafeMutablePointer(mutating: cWord.pronunciation))
      }

      let resultCode = withUUIDTuple(bytes: &uuidBytes) { tuplePtr in
        voicevox_user_dict_add_word(pointer, &cWord, tuplePtr)
      }

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "add",
          details: "Failed to add word '\(word.surface)' with error code: \(resultCode)"
        )
      }

      return makeUUID(from: uuidBytes)
    }
  }

  private func performLocked<T>(_ body: () throws -> T) throws(VOICEVOXError) -> T {
    do {
      return try lock.withLockUnchecked(body)
    } catch let error as VOICEVOXError {
      throw error
    } catch {
      throw VOICEVOXError.internalError(details: "Unexpected error: \(error)")
    }
  }

  private func makeUUID(from bytes: [UInt8]) -> UUID {
    bytes.withUnsafeBufferPointer { ptr in
      ptr.baseAddress!
        .withMemoryRebound(to: uuid_t.self, capacity: 1) { uuidPtr in
          UUID(uuid: uuidPtr.pointee)
        }
    }
  }

  // swiftlint:disable:next large_tuple
  private typealias UUIDTuple = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )

  private func withUUIDTuple<T>(
    bytes: inout [UInt8],
    _ body: (UnsafeMutablePointer<UUIDTuple>) throws -> T
  ) rethrows -> T {
    try bytes.withUnsafeMutableBytes { ptr in
      try ptr.baseAddress!
        .withMemoryRebound(to: UUIDTuple.self, capacity: 1, body)
    }
  }

  private func withUUIDTuple<T>(
    uuid: UUID,
    _ body: (UnsafePointer<UUIDTuple>) throws -> T
  ) rethrows -> T {
    let uuidBytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
    return try uuidBytes.withUnsafeBufferPointer { ptr in
      try ptr.baseAddress!
        .withMemoryRebound(to: UUIDTuple.self, capacity: 1, body)
    }
  }

  /// Updates a word in the dictionary
  /// - Parameters:
  ///   - uuid: UUID of the word to update
  ///   - word: New word data
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func updateWord(uuid: UUID, word: Word) throws(VOICEVOXError) {
    try performLocked {
      var cWord = word.toCStruct()
      defer {
        free(UnsafeMutablePointer(mutating: cWord.surface))
        free(UnsafeMutablePointer(mutating: cWord.pronunciation))
      }

      let resultCode = withUUIDTuple(uuid: uuid) { tuplePtr in
        voicevox_user_dict_update_word(pointer, tuplePtr, &cWord)
      }

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "update",
          details: "Failed to update word with UUID: \(uuid), error code: \(resultCode)"
        )
      }
    }
  }

  /// Removes a word from the dictionary
  /// - Parameter uuid: UUID of the word to remove
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func removeWord(uuid: UUID) throws(VOICEVOXError) {
    try performLocked {
      let resultCode = withUUIDTuple(uuid: uuid) { tuplePtr in
        voicevox_user_dict_remove_word(pointer, tuplePtr)
      }

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "remove",
          details: "Failed to remove word with UUID: \(uuid), error code: \(resultCode)"
        )
      }
    }
  }

  /// Loads user dictionary from a file
  /// - Parameter url: URL of the dictionary file to load
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func load(from url: URL) throws(VOICEVOXError) {
    try performLocked {
      let path = url.absoluteURL.path()
      let resultCode = voicevox_user_dict_load(pointer, path)

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "load",
          details: "Failed to load user dictionary from: \(url), error code: \(resultCode)"
        )
      }
    }
  }

  /// Saves user dictionary to a file
  /// - Parameter url: URL where the dictionary will be saved
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func save(to url: URL) throws(VOICEVOXError) {
    try performLocked {
      let path = url.absoluteURL.path()
      let resultCode = voicevox_user_dict_save(pointer, path)

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "save",
          details: "Failed to save user dictionary to: \(url), error code: \(resultCode)"
        )
      }
    }
  }

  /// Imports another user dictionary
  /// - Parameter otherDict: User dictionary to import
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func importDictionary(_ otherDict: UserDictionary) throws(VOICEVOXError) {
    try performLocked {
      let resultCode = voicevox_user_dict_import(pointer, otherDict.pointer)

      guard resultCode == 0 else {
        throw VOICEVOXError.userDictError(
          operation: "import",
          details: "Failed to import user dictionary, error code: \(resultCode)"
        )
      }
    }
  }

  /// Gets the user dictionary contents in JSON format
  /// - Returns: JSON data representing the dictionary contents
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func toJSON() throws(VOICEVOXError) -> Data {
    try performLocked {
      var jsonPtr: UnsafeMutablePointer<CChar>?
      let resultCode = voicevox_user_dict_to_json(pointer, &jsonPtr)

      guard resultCode == 0, let jsonPtr else {
        throw VOICEVOXError.userDictError(
          operation: "toJSON",
          details: "Failed to convert user dictionary to JSON, error code: \(resultCode)"
        )
      }

      defer { voicevox_json_free(jsonPtr) }
      return Data(bytes: jsonPtr, count: strlen(jsonPtr))
    }
  }

  /// Gets all words in the dictionary
  /// - Returns: Array of all words in the dictionary
  /// - Throws: ``VOICEVOXError/userDictError(operation:details:)`` if the operation fails
  public func words() throws(VOICEVOXError) -> [Word] {
    let jsonData = try toJSON()

    do {
      let jsonDict = try JSONDecoder().decode([String: JSONWord].self, from: jsonData)
      return jsonDict.map { uuid, jsonWord in
        Word(
          id: UUID(uuidString: uuid) ?? UUID(),
          surface: jsonWord.surface,
          pronunciation: jsonWord.pronunciation,
          accentType: jsonWord.accentType,
          wordType: mapWordType(from: jsonWord),
          priority: jsonWord.priority
        )
      }
    } catch {
      throw VOICEVOXError.userDictError(
        operation: "words",
        details: "Failed to decode user dictionary JSON: \(error)"
      )
    }
  }

  private func mapWordType(from jsonWord: JSONWord) -> WordType {
    switch (jsonWord.partOfSpeech, jsonWord.partOfSpeechDetail1) {
    case ("名詞", "固有名詞"):
      return .properNoun
    case ("名詞", _):
      return .commonNoun
    case ("動詞", _):
      return .verb
    case ("形容詞", _):
      return .adjective
    case ("接尾辞", _), ("接尾", _):
      return .suffix
    default:
      return .properNoun
    }
  }

  // Internal method for OpenJTalk integration
  func getCPointer() -> OpaquePointer {
    pointer
  }
}
