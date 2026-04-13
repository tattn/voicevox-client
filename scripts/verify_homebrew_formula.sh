#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmpdir="$(mktemp -d)"
dist_dir="${tmpdir}/dist"
tap_name="local/voicevox-client-verify-$RANDOM"
tap_dir=''
formula_path=''
installed_by_script=0

cleanup() {
  if [[ "$installed_by_script" == "1" ]] && brew list --formula voicevox-client >/dev/null 2>&1; then
    brew uninstall --force voicevox-client >/dev/null 2>&1 || true
  fi
  if [[ -n "$tap_dir" ]] && brew tap | grep -qx "$tap_name"; then
    brew untap "$tap_name" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if brew list --formula voicevox-client >/dev/null 2>&1; then
  echo "voicevox-client is already installed in Homebrew. Uninstall it first or verify manually." >&2
  exit 2
fi

brew tap-new --no-git "$tap_name" >/dev/null
tap_dir="$(brew --repository "$tap_name")"
formula_path="${tap_dir}/Formula/voicevox-client.rb"

mkdir -p "$dist_dir"
"${repo_root}/scripts/build_release_archive.sh" \
  --version "0.0.0-local" \
  --output-dir "$dist_dir"

archive_path="$(find "$dist_dir" -maxdepth 1 -name 'voicevox-client-0.0.0-local-macos-*.tar.gz' | head -n1)"
if [[ -z "$archive_path" ]]; then
  echo "Failed to locate built release archive." >&2
  exit 1
fi

sha256="$(shasum -a 256 "$archive_path" | awk '{print $1}')"

"${repo_root}/scripts/generate_homebrew_formula.sh" \
  --arm64-url "file://${archive_path}" \
  --arm64-sha256 "$sha256" \
  --x86_64-url "file://${archive_path}" \
  --x86_64-sha256 "$sha256" \
  --homepage "https://example.invalid/voicevox-client" \
  --version "0.0.0-local" \
  --output "$formula_path"

HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 brew install "$formula_path"
installed_by_script=1
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 brew test voicevox-client
