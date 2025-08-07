# VOICEVOX iOS Client

An unofficial VOICEVOX client for iOS.

## Requirements

You need to provide and save the resources in `./Example/VOICEVOXExample/lib`:

- **Open JTalk dictionary** - Japanese text analysis dictionary
- **VVM files** - VOICEVOX voice model files

```
lib
├── open_jtalk_dic_utf_8
│   ├── char.bin
│   └── ...
└── vvms
    ├── 0.vvm
    └── ...
```

Refer to the [VOICEVOX documentation](https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/downloader.md) for details.

## Quick Start

```swift
import VOICEVOX

// Configure
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: URL(fileURLWithPath: "/path/to/open_jtalk_dic"),
    accelerationMode: .auto  // .auto, .cpu, or .gpu
)

// Initialize
let synthesizer = try await VOICEVOXSynthesizer(configuration: config)

// Load voice model
let modelURL = URL(fileURLWithPath: "/path/to/model.vvm")
let modelID = try await synthesizer.loadVoiceModel(from: modelURL)

// Generate speech
let audioData = try await synthesizer.synthesize(
    text: "こんにちは",
    styleId: 0,
    options: TTSOptions(enableInterrogativeUpspeak: true)
)

// audioData contains WAV format audio ready for playback
```
