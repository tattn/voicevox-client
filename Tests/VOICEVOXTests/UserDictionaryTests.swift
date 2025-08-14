import Foundation
import Testing

@testable import VOICEVOX

struct UserDictionaryTests {
  @Test
  func testUserDictionaryWordCreation() {
    let word = UserDictionary.Word(
      surface: "手札",
      pronunciation: "テフダ",
      accentType: 1,
      wordType: .properNoun,
      priority: 6
    )

    #expect(word.surface == "手札")
    #expect(word.pronunciation == "テフダ")
    #expect(word.accentType == 1)
    #expect(word.wordType == .properNoun)
    #expect(word.priority == 6)
  }

  @Test
  func testUserDictionaryWordDefaultValues() {
    let word = UserDictionary.Word(
      surface: "AI",
      pronunciation: "エーアイ",
      accentType: 2
    )

    #expect(word.surface == "AI")
    #expect(word.pronunciation == "エーアイ")
    #expect(word.accentType == 2)
    #expect(word.wordType == .properNoun)
    #expect(word.priority == 5)
  }

  @Test
  func testUserDictionaryCreation() {
    _ = UserDictionary()
    // Test creation
  }

  @Test
  func testUserDictionaryAddWord() throws {
    let dictionary = UserDictionary()
    let word = UserDictionary.Word(
      surface: "VOICEVOX",
      pronunciation: "ボイスボックス",
      accentType: 4,
      wordType: .properNoun,
      priority: 10
    )

    do {
      _ = try dictionary.addWord(word)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testUserDictionaryUpdateWord() throws {
    let dictionary = UserDictionary()

    do {
      let originalWord = UserDictionary.Word(
        surface: "初期値",
        pronunciation: "ショキチ",
        accentType: 1
      )
      let uuid = try dictionary.addWord(originalWord)

      let updatedWord = UserDictionary.Word(
        surface: "更新値",
        pronunciation: "コウシンチ",
        accentType: 2,
        wordType: .commonNoun,
        priority: 8
      )

      try dictionary.updateWord(uuid: uuid, word: updatedWord)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testUserDictionaryRemoveWord() throws {
    let dictionary = UserDictionary()

    do {
      let word = UserDictionary.Word(
        surface: "削除対象",
        pronunciation: "サクジョタイショウ",
        accentType: 5
      )
      let uuid = try dictionary.addWord(word)
      try dictionary.removeWord(uuid: uuid)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testUserDictionaryImport() throws {
    let dictionary1 = UserDictionary()
    let dictionary2 = UserDictionary()

    do {
      let word1 = UserDictionary.Word(
        surface: "単語1",
        pronunciation: "タンゴイチ",
        accentType: 3
      )
      let word2 = UserDictionary.Word(
        surface: "単語2",
        pronunciation: "タンゴニ",
        accentType: 2
      )

      _ = try dictionary2.addWord(word1)
      _ = try dictionary2.addWord(word2)

      try dictionary1.importDictionary(dictionary2)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testUserDictionaryToJSON() throws {
    let dictionary = UserDictionary()

    do {
      let word1 = UserDictionary.Word(
        surface: "JSON",
        pronunciation: "ジェイソン",
        accentType: 3,
        wordType: .properNoun
      )
      let word2 = UserDictionary.Word(
        surface: "API",
        pronunciation: "エーピーアイ",
        accentType: 4,
        wordType: .properNoun
      )

      _ = try dictionary.addWord(word1)
      _ = try dictionary.addWord(word2)

      let jsonData = try dictionary.toJSON()
      #expect(!jsonData.isEmpty)

      _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testUserDictionarySaveAndLoad() throws {
    let dictionary1 = UserDictionary()

    do {
      let word = UserDictionary.Word(
        surface: "保存テスト",
        pronunciation: "ホゾンテスト",
        accentType: 5
      )
      _ = try dictionary1.addWord(word)

      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_user_dict.json")
      defer {
        try? FileManager.default.removeItem(at: tempURL)
      }

      try dictionary1.save(to: tempURL)

      let dictionary2 = UserDictionary()
      try dictionary2.load(from: tempURL)

      let jsonData = try dictionary2.toJSON()
      #expect(!jsonData.isEmpty)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testAllWordTypes() throws {
    let wordTypes: [UserDictionary.WordType] = [
      .properNoun,
      .commonNoun,
      .verb,
      .adjective,
      .suffix,
    ]

    let dictionary = UserDictionary()

    do {
      for wordType in wordTypes {
        let word = UserDictionary.Word(
          surface: "テスト\(wordType)",
          pronunciation: "テスト",
          accentType: 1,
          wordType: wordType
        )

        _ = try dictionary.addWord(word)
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testWordPriorityRange() throws {
    let dictionary = UserDictionary()

    do {
      let lowPriorityWord = UserDictionary.Word(
        surface: "低優先度",
        pronunciation: "テイユウセンド",
        accentType: 1,
        priority: 1
      )
      _ = try dictionary.addWord(lowPriorityWord)

      let highPriorityWord = UserDictionary.Word(
        surface: "高優先度",
        pronunciation: "コウユウセンド",
        accentType: 1,
        priority: 10
      )
      _ = try dictionary.addWord(highPriorityWord)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func testWordIdentifiable() {
    let word1 = UserDictionary.Word(
      surface: "単語1",
      pronunciation: "タンゴイチ",
      accentType: 1
    )
    let word2 = UserDictionary.Word(
      surface: "単語2",
      pronunciation: "タンゴニ",
      accentType: 2
    )

    #expect(word1.id != word2.id)
    #expect(type(of: word1.id) == UUID.self)
  }

  @Test
  func testWordEquatable() {
    let id = UUID()
    let word1 = UserDictionary.Word(
      id: id,
      surface: "単語",
      pronunciation: "タンゴ",
      accentType: 1
    )
    let word2 = UserDictionary.Word(
      id: id,
      surface: "単語",
      pronunciation: "タンゴ",
      accentType: 1
    )
    let word3 = UserDictionary.Word(
      surface: "単語",
      pronunciation: "タンゴ",
      accentType: 1
    )

    #expect(word1 == word2)
    #expect(word1 != word3)
  }

  @Test
  func testWordHashable() {
    let word = UserDictionary.Word(
      surface: "テスト",
      pronunciation: "テスト",
      accentType: 1
    )

    var set = Set<UserDictionary.Word>()
    set.insert(word)
    #expect(set.contains(word))

    let dictionary = [word: "value"]
    #expect(dictionary[word] == "value")
  }

  @Test
  func testWordTypeEquatable() {
    let wordType1 = UserDictionary.WordType.properNoun
    let wordType2 = UserDictionary.WordType.properNoun
    let wordType3 = UserDictionary.WordType.commonNoun

    #expect(wordType1 == wordType2)
    #expect(wordType1 != wordType3)
  }

  @Test
  func testWordTypeHashable() {
    let wordType = UserDictionary.WordType.verb

    var set = Set<UserDictionary.WordType>()
    set.insert(wordType)
    #expect(set.contains(wordType))

    let dictionary = [wordType: "value"]
    #expect(dictionary[wordType] == "value")
  }
}
