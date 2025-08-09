#!/bin/bash
set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Get the project root directory (parent of scripts directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root directory
cd "$PROJECT_ROOT"

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
curl -L https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.0/download-osx-arm64 -o download
chmod +x download

echo "Extracting VOICEVOX resources..."
echo -e "y\n" | ./download --output voicevox_resources  --only models
echo -e "y\n" | ./download --output voicevox_resources  --only dict
echo -e "y\n" | ./download --output voicevox_resources  --only onnxruntime

echo "Downloading VOICEVOX Core library..."
curl -L https://github.com/VOICEVOX/voicevox_core/releases/download/0.16.0/voicevox_core-osx-arm64-0.16.0.zip -o voicevox_core.zip
unzip -q voicevox_core.zip

echo "Setting up VOICEVOX resources..."
mkdir -p ./Example/VOICEVOXExample/lib
cp -r voicevox_resources/models/vvms ./Example/VOICEVOXExample/lib
cp -r voicevox_resources/dict/open_jtalk_dic_utf_8-1.11 ./Example/VOICEVOXExample/lib/open_jtalk_dic_utf_8
cp voicevox_core-osx-arm64-0.16.0/lib/libvoicevox_core.dylib ./Example/VOICEVOXExample/lib
cp voicevox_resources/onnxruntime/lib/libvoicevox_onnxruntime.1.17.3.dylib ./Example/VOICEVOXExample/lib

echo "Updating dylib install names..."
install_name_tool -id @rpath/libvoicevox_core.dylib ./Example/VOICEVOXExample/lib/libvoicevox_core.dylib

# Clean up downloaded files
rm -f download
rm -f voicevox_core.zip
rm -rf voicevox_resources
rm -rf voicevox_core-osx-arm64-0.16.0

echo "VOICEVOX resources setup complete!"