# ``VOICEVOX``

A Swift client library for VOICEVOX text-to-speech synthesis engine.

## Overview

VOICEVOX is a powerful Swift library that provides seamless integration with the VOICEVOX Core text-to-speech engine. It enables iOS and macOS applications to generate high-quality Japanese speech from text using neural network-based voice synthesis.

## Getting Started

### Basic Setup

To start using VOICEVOX, you need to:
1. Create a configuration
2. Initialize the synthesizer
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

### Audio Query Workflow

For fine-grained control over the synthesis process, you can work with AudioQuery objects:

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

## Platform-Specific Configuration

### iOS

On iOS, the library automatically handles the embedded ONNX Runtime:

```swift
#if os(iOS)
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: Bundle.main.url(forResource: "open_jtalk_dic", withExtension: nil)!
)
#endif
```

### macOS

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

- ``Synthesizer``
- ``VOICEVOXConfiguration``
- ``VOICEVOXError``

### Voice Models and Speakers

- ``VoiceModelFile``
- ``VoiceModelID``
- ``Speaker``

### Audio Generation

- ``AudioQuery``
- ``AudioQuery/AccentPhrase``
- ``AudioQuery/Mora``
- ``AudioQuery/PauseMora``

### Configuration

- ``TTSOptions``
- ``AccelerationMode``
