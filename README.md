# VOICEVOX iOS Client

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/voicevox-client/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/voicevox-client/actions/workflows/test.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2Fvoicevox-client%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/tattn/voicevox-client)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2Fvoicevox-client%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/tattn/voicevox-client)

An unofficial VOICEVOX client for iOS.

## Setup

### Automatic Setup

Run the setup script to automatically download and configure all required resources:

```bash
./scripts/setup-voicevox-resources.sh
```

This script will download and set up:
- **VOICEVOX Core library** (`libvoicevox_core.dylib`)
- **ONNX Runtime library** (`libvoicevox_onnxruntime.dylib`)
- **Open JTalk dictionary** - Japanese text analysis dictionary
- **VVM files** - VOICEVOX voice model files

<details>
<summary><h3>Manual Setup</h3></summary>

If you prefer manual setup, you need to provide and save the resources in `./Example/VOICEVOXExample/lib`:

- **VOICEVOX Core library** (`libvoicevox_core.dylib`)
- **ONNX Runtime library** (`libvoicevox_onnxruntime.1.17.3.dylib`)
- **Open JTalk dictionary** - Japanese text analysis dictionary
- **VVM files** - VOICEVOX voice model files

```
lib
├── libvoicevox_core.dylib
├── libvoicevox_onnxruntime.1.17.3.dylib
├── open_jtalk_dic_utf_8
│   ├── char.bin
│   └── ...
└── vvms
    ├── 0.vvm
    └── ...
```

Refer to the [VOICEVOX documentation](https://github.com/VOICEVOX/voicevox_core/blob/main/docs/guide/user/downloader.md) for details.

</details>

## Quick Start

```swift
import VOICEVOX

// Configure
let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: URL(fileURLWithPath: "/path/to/open_jtalk_dic")
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