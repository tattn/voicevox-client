# `VOICEVOX`

A Swift client library for VOICEVOX text-to-speech synthesis engine.

## Overview

VOICEVOX is a powerful Swift library that provides seamless integration with the VOICEVOX Core text-to-speech engine. It enables iOS and macOS applications to generate high-quality Japanese speech from text using neural network-based voice synthesis.

## Getting Started

To start using VOICEVOX in your application, follow these steps:

1. Create a `VOICEVOXConfiguration`
2. Initialize the `Synthesizer`
3. Load voice models
4. Generate speech from text

```swift
import VOICEVOX

// Create configuration with dictionary path
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: dictionaryURL
)

// Initialize the synthesizer
let synthesizer = try await Synthesizer(configuration: config)

// Load a voice model
let modelID = try await synthesizer.loadVoiceModel(from: voiceModelURL)

// Synthesize speech
let audioData = try await synthesizer.synthesize(
    text: "こんにちは",
    styleId: 0
)
```

## Advanced Usage

### Working with Audio Queries

For fine-grained control over the synthesis process, you can work with `AudioQuery` objects:

```swift
// Step 1: Create an audio query from text
let audioQuery = try await synthesizer.makeAudioQuery(
    text: "テスト音声",
    styleId: 0
)

// Step 2: Modify audio query parameters
let modifiedQuery = AudioQuery(
    accentPhrases: audioQuery.accentPhrases,
    speedScale: 1.5,        // Speed up speech
    pitchScale: 0.1,        // Slightly higher pitch
    intonationScale: 1.2,   // More expressive intonation
    volumeScale: audioQuery.volumeScale,
    prePhonemeLength: audioQuery.prePhonemeLength,
    postPhonemeLength: audioQuery.postPhonemeLength,
    outputSamplingRate: audioQuery.outputSamplingRate,
    outputStereo: audioQuery.outputStereo,
    kana: audioQuery.kana
)

// Step 3: Synthesize using the modified query
let audioData = try await synthesizer.synthesize(
    audioQuery: modifiedQuery,
    styleId: 0
)
```

### Validating Audio Queries

`AudioQuery`, `AudioQuery.AccentPhrase` and `AudioQuery.Mora` can be validated before synthesis. Validation throws `VOICEVOXError.invalidQuery` with the reason reported by VOICEVOX Core:

```swift
var query = try await synthesizer.makeAudioQuery(text: "テスト", styleId: 0)
query.accentPhrases[0].accent = 10
try query.validate() // throws VOICEVOXError.invalidQuery(kind: .audioQuery, reason: ...)
```

### Reloading Voice Models

`loadVoiceModel(from:)` skips a voice model that is already loaded. VOICEVOX Core keeps a large amount of memory occupied after synthesizing long text, and reloading the voice model releases it:

```swift
try await synthesizer.loadVoiceModel(from: voiceModelURL, onExisting: .reload)
```

### Singing Synthesis

Singing synthesis creates a `FrameAudioQuery` from a `Score` and synthesizes it. The first note of a score must be a rest. `frameLength` is the length in frames (93.75 frames per second).

```swift
// Load a voice model containing singing styles (e.g. s0.vvm)
try await synthesizer.loadVoiceModel(from: songVoiceModelURL)

let score = Score(notes: [
    .rest(frameLength: 15),
    Score.Note(key: 60, lyric: "ド", frameLength: 45),
    Score.Note(key: 62, lyric: "レ", frameLength: 45),
    Score.Note(key: 64, lyric: "ミ", frameLength: 45),
    .rest(frameLength: 15),
])

// Use a `singing_teacher` or `sing` style to create the query
let frameAudioQuery = try await synthesizer.createSingFrameAudioQuery(score: score, styleId: 6000)

// Use a `frame_decode` or `sing` style to synthesize
let audioData = try await synthesizer.synthesize(frameAudioQuery: frameAudioQuery, styleId: 3000)
```

After editing the phonemes of a `FrameAudioQuery`, regenerate the fundamental frequency and the volume with `createSingFrameF0(score:frameAudioQuery:styleId:)` and `createSingFrameVolume(score:frameAudioQuery:styleId:)`. `FrameAudioQuery.ensureCompatible(with:)` checks whether a score and a query can be used together.

The available operations of a style are given by `Speaker.Style.styleType`.

### Custom Pronunciation with User Dictionary

The `UserDictionary` class allows you to register custom words with specific pronunciations and accent patterns. This is particularly useful for proper nouns, technical terms, or any words that may not be in the standard dictionary.

#### Creating and Managing Words

```swift
// Create a user dictionary
let dictionary = UserDictionary()

// Add custom words
var word = UserDictionary.Word(
    surface: "VOICEVOX",
    pronunciation: "ボイスボックス",
    accentType: 4,
    wordType: .properNoun,
    priority: 10
)
try dictionary.addWord(&word)

// Register multiple words
var techWord = UserDictionary.Word(
    surface: "Swift",
    pronunciation: "スウィフト",
    accentType: 3,
    wordType: .properNoun
)
try dictionary.addWord(&techWord)

// Initialize synthesizer with configuration
let synthesizer = try await Synthesizer(configuration: config)

// Apply the user dictionary to the synthesizer
try await synthesizer.setUserDictionary(dictionary)

// Now synthesis will use your custom pronunciations
let audioData = try await synthesizer.synthesize(
    text: "VOICEVOXをSwiftで使う",
    styleId: 0
)
```

#### Managing Dictionary Entries

Each word added to the dictionary has its `id` property set to a unique `UUID` that can be used to update or remove entries:

```swift
// Update an existing word by modifying its properties
word.pronunciation = "ボイボ"  // Shortened pronunciation
word.accentType = 2
try dictionary.updateWord(word)

// Remove a word
try dictionary.removeWord(id: word.id)

// Save/Load dictionary
let fileURL = documentsDirectory.appendingPathComponent("custom_dict.json")
try dictionary.save(to: fileURL)

let loadedDict = UserDictionary()
try loadedDict.load(from: fileURL)

// Import from another dictionary
let anotherDict = UserDictionary()
try dictionary.importDictionary(anotherDict)

// Export as JSON
let jsonData = try dictionary.toJSON()
```

### Platform-Specific Configuration

#### iOS Configuration

On iOS, the library automatically handles the embedded ONNX Runtime:

```swift
#if os(iOS)
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: Bundle.main.url(forResource: "open_jtalk_dic", withExtension: nil)!
)
#endif
```

#### macOS Configuration

On macOS, you need to specify the ONNX Runtime directory:

```swift
#if os(macOS)
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: openJTalkDictURL,
    onnxruntimeDirectoryURL: onnxRuntimeURL
)
#endif
```

## Topics

### Essentials

- `Synthesizer`
- `VOICEVOXConfiguration`
- `VOICEVOXError`

### Voice Models

- `VoiceModelFile`
- `VoiceModelID`
- `Speaker`
- `Speaker/Style`
- `Speaker/StyleType`
- `ExistingVoiceModelBehavior`

### Audio Generation

- `AudioQuery`
- `AudioQuery/AccentPhrase`
- `AudioQuery/Mora`
- `AudioQuery/PauseMora`

### Singing Synthesis

- `Score`
- `Score/Note`
- `FrameAudioQuery`
- `FrameAudioQuery/FramePhoneme`

### Text Processing

- `OpenJTalk`
- `UserDictionary`
- `UserDictionary/Word`
- `UserDictionary/WordType`

### Configuration Options

- `TTSOptions`
- `AccelerationMode`

### Synthesis Options

- `SynthesisOptions`
