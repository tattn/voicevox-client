#!/bin/bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Get the project root directory (parent of scripts directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT"

github_token() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        printf '%s' "${GITHUB_TOKEN}"
    elif [ -n "${GH_TOKEN:-}" ]; then
        printf '%s' "${GH_TOKEN}"
    fi
}

curl_github_release() {
    local url="$1"
    local output="$2"
    local token
    token="$(github_token)"

    if [ -n "$token" ]; then
        curl -fL -H "Authorization: Bearer ${token}" "$url" -o "$output"
    else
        curl -fL "$url" -o "$output"
    fi
}

voicevox_release_arch() {
    case "$(uname -m)" in
        arm64)
            printf '%s' 'arm64'
            ;;
        x86_64)
            printf '%s' 'x64'
            ;;
        *)
            uname -m
            ;;
    esac
}

# Check if resources already exist
VVMS_DIR="./Example/VOICEVOXExample/lib/vvms"
DICT_DIR="./Example/VOICEVOXExample/lib/open_jtalk_dic_utf_8"
CORE_LIB="./Example/VOICEVOXExample/lib/libvoicevox_core.dylib"
ONNX_LIB="./Example/VOICEVOXExample/lib/libvoicevox_onnxruntime.1.17.3.dylib"

if [ -d "$VVMS_DIR" ] && [ -d "$DICT_DIR" ] && [ -f "$CORE_LIB" ] && [ -f "$ONNX_LIB" ]; then
    echo "VOICEVOX resources already exist, skipping download..."
    # Check if directories are not empty
    if [ "$(ls -A "$VVMS_DIR" 2>/dev/null)" ] && [ "$(ls -A "$DICT_DIR" 2>/dev/null)" ]; then
        echo "VOICEVOX resources verified successfully!"
        exit 0
    else
        echo "VOICEVOX resource directories exist but are empty, proceeding with download..."
    fi
fi

echo "Downloading VOICEVOX resources..."
ARCH="$(voicevox_release_arch)"
curl_github_release "https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.3/download-osx-${ARCH}" download
chmod +x download
xattr -d com.apple.quarantine download 2>/dev/null || true

echo "Extracting VOICEVOX resources..."
run_download() {
    local only="$1"
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        printf "y\n" | PAGER=/bin/cat ./download --output voicevox_resources --only "$only"
        return
    fi

    # Avoid pager errors by running under a pseudo-TTY locally.
    if command -v script >/dev/null 2>&1; then
        script -q /dev/null bash -lc "printf 'y\n' | PAGER=/bin/cat ./download --output voicevox_resources --only $only"
    else
        printf "y\n" | PAGER=/bin/cat ./download --output voicevox_resources --only "$only"
    fi
}

run_download models
run_download dict
run_download onnxruntime

echo "Downloading VOICEVOX Core library..."
curl_github_release "https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.3/voicevox_core-osx-${ARCH}-0.16.3.zip" voicevox_core.zip
unzip -q voicevox_core.zip

echo "Setting up VOICEVOX resources..."
mkdir -p ./Example/VOICEVOXExample/lib
cp -r voicevox_resources/models/vvms ./Example/VOICEVOXExample/lib
cp -r voicevox_resources/dict/open_jtalk_dic_utf_8-1.11 ./Example/VOICEVOXExample/lib/open_jtalk_dic_utf_8
cp "voicevox_core-osx-${ARCH}-0.16.3/lib/libvoicevox_core.dylib" ./Example/VOICEVOXExample/lib
cp voicevox_resources/onnxruntime/lib/libvoicevox_onnxruntime.1.17.3.dylib ./Example/VOICEVOXExample/lib

echo "Updating dylib install names..."
install_name_tool -id @rpath/libvoicevox_core.dylib ./Example/VOICEVOXExample/lib/libvoicevox_core.dylib

# Clean up downloaded files
rm -f download
rm -f voicevox_core.zip
rm -rf voicevox_resources
rm -rf "voicevox_core-osx-${ARCH}-0.16.3"

echo "VOICEVOX resources setup complete!"
