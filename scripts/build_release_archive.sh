#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOS'
Usage:
  build_release_archive.sh \
    --version <version> \
    [--output-dir <dir>]

Example:
  ./scripts/build_release_archive.sh --version 0.1.0
EOS
}

output_dir='dist'
version=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "--version is required." >&2
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
arch="$(uname -m)"
stage_dir="$(mktemp -d)"
archive_name="voicevox-client-${version}-macos-${arch}.tar.gz"
archive_path="${output_dir}/${archive_name}"

cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT

mkdir -p "$output_dir"

swift build -c release --product voicevox-client
cp "${repo_root}/.build/release/voicevox-client" "${stage_dir}/voicevox-client"
chmod +x "${stage_dir}/voicevox-client"
tar -C "$stage_dir" -czf "$archive_path" voicevox-client
shasum -a 256 "$archive_path" > "${archive_path}.sha256"

echo "$archive_path"
