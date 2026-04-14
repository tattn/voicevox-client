# VOICEVOX Client for iOS and macOS

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/tattn/voicevox-client/actions/workflows/test.yml/badge.svg)](https://github.com/tattn/voicevox-client/actions/workflows/test.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2Fvoicevox-client%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/tattn/voicevox-client)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftattn%2Fvoicevox-client%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/tattn/voicevox-client)

An unofficial VOICEVOX client for iOS and macOS.

## CLI

### Install with Homebrew

```bash
brew tap tattn/voicevox-client
brew install voicevox-client
```

### Setup

```bash
voicevox-client setup
```

Resources are saved to `~/.voicevox-client/resources/`.

Set `VOICEVOX_CLIENT_HOME` to change the base directory (default: `~/.voicevox-client`).

### Usage

```bash
# Synthesize speech (uses default resources)
voicevox-client --text "こんにちは"

# Specify style and output
voicevox-client --text "こんにちは" --style-id 1 --output greeting.wav

# Adjust speech parameters
voicevox-client --text "こんにちは" --speed 1.2 --pitch 0.8

# AquesTalk-like kana notation (control accent directly)
voicevox-client --text "コンニチワ'" --kana

# Use a specific voice model by name (loads <resources>/vvms/<name>.vvm)
voicevox-client --text "こんにちは" --model-name 1

# List speakers in the current model
voicevox-client speakers

# List all speakers from all downloaded models
voicevox-client speakers --all
```

<details>
<summary>AquesTalk-like kana notation reference</summary>

The `--kana` flag accepts katakana with special symbols to control accent and intonation:

| Symbol | Description | Example |
|---|---|---|
| `'` | Accent position (required once per phrase) | `コンニチワ'` |
| `/` | Accent phrase separator | `コンニチワ'/ゲンキデ'スカ` |
| `、` | Accent phrase separator with pause | `コンニチワ'、ゲンキデ'スカ` |
| `_` | Unvoiced mora (place before kana) | `ス_キデ'ス` |
| `？` | Interrogative intonation (place at end) | `ゲンキデ'スカ？` |

</details>

<details>
<summary>Audio query (JSON) workflow</summary>

You can export an audio query as JSON, edit it, and then synthesize from it:

```bash
# Generate audio query JSON
voicevox-client query --text "こんにちは" --style-id 0 > query.json

# Save to a file directly
voicevox-client query --text "こんにちは" --style-id 0 --output query.json

# Synthesize from a JSON file
voicevox-client synthesize-from-query --input query.json --style-id 0 --output output.wav

# Pipe directly
voicevox-client query --text "こんにちは" | voicevox-client synthesize-from-query --input - --output output.wav
```

</details>

## Swift Library

The API documentation is available [here](https://tattn.github.io/voicevox-client/documentation/voicevox).

```swift
import VOICEVOX

let config = VOICEVOXConfiguration(
    openJTalkDictionaryURL: Bundle.main.url(forResource: "open_jtalk_dic", withExtension: nil)!
)

let synthesizer = try await Synthesizer(configuration: config)
try await synthesizer.loadVoiceModel(from: modelURL)

let audioData = try await synthesizer.synthesize(text: "こんにちは", styleId: 0)

// AquesTalk-like kana notation for direct accent control
let audioData = try await synthesizer.synthesize(kana: "コンニチワ'", styleId: 0)
```

## Example App Setup

```bash
./scripts/setup-voicevox-resources.sh
```

This downloads VOICEVOX Core, ONNX Runtime, OpenJTalk dictionary, and voice models to `Example/VOICEVOXExample/lib/`.
If you hit GitHub release rate limits, set `GITHUB_TOKEN` or `GH_TOKEN` before running it.
