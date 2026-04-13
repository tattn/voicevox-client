#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOS'
Usage:
  generate_homebrew_formula.sh \
    --arm64-url <archive-url> \
    --arm64-sha256 <sha256> \
    --x86_64-url <archive-url> \
    --x86_64-sha256 <sha256> \
    --homepage <homepage-url> \
    --version <version> \
    [--license <spdx-license>] \
    [--desc <description>] \
    [--output <formula-path>]
EOS
}

desc='Unofficial VOICEVOX CLI for macOS'
formula_path='Formula/voicevox-client.rb'
arm64_sha256=''
arm64_url=''
homepage=''
license='MIT'
version=''
x86_64_sha256=''
x86_64_url=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arm64-url)
      arm64_url="${2:-}"
      shift 2
      ;;
    --arm64-sha256)
      arm64_sha256="${2:-}"
      shift 2
      ;;
    --x86_64-url)
      x86_64_url="${2:-}"
      shift 2
      ;;
    --x86_64-sha256)
      x86_64_sha256="${2:-}"
      shift 2
      ;;
    --homepage)
      homepage="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
      shift 2
      ;;
    --license)
      license="${2:-}"
      shift 2
      ;;
    --desc)
      desc="${2:-}"
      shift 2
      ;;
    --output)
      formula_path="${2:-}"
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

if [[ -z "$arm64_url" || -z "$arm64_sha256" || -z "$x86_64_url" || -z "$x86_64_sha256" || -z "$homepage" || -z "$version" ]]; then
  echo "--arm64-url, --arm64-sha256, --x86_64-url, --x86_64-sha256, --homepage, and --version are required." >&2
  usage >&2
  exit 2
fi

formula_dir="$(dirname "$formula_path")"
mkdir -p "$formula_dir"

license_line=''
if [[ -n "$license" ]]; then
  license_line="  license \"${license}\""
fi

cat >"$formula_path" <<EOS
class VoicevoxClient < Formula
  desc "${desc}"
  homepage "${homepage}"
  version "${version}"
${license_line}

  on_macos do
    on_arm do
      url "${arm64_url}"
      sha256 "${arm64_sha256}"
    end

    on_intel do
      url "${x86_64_url}"
      sha256 "${x86_64_sha256}"
    end
  end

  def install
    bin.install "voicevox-client"
    bin.install "libvoicevox_core.dylib"
    bin.install "libvoicevox_onnxruntime.1.17.3.dylib"
  end

  test do
    output = shell_output("#{bin}/voicevox-client --help")
    assert_match "VOICEVOX text-to-speech CLI tool", output
    assert_match "setup", output
  end
end
EOS

echo "Wrote ${formula_path}"
