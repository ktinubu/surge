#!/usr/bin/env bash
# ==============================================================================
# run.sh — reproduce the canonical example for surge (Surge XT).
# Idempotent: safe to re-run. Verified on Apple M5 Max / macOS arm64.
#
# Depth: smoke. Initializes submodules, configures CMake+Ninja Release, builds
# ONLY the surge-xt-cli target (headless CLI, not the full VST3/AU/CLAP/
# Standalone plugin set), then runs --version / --help / --list-devices.
#
# Usage:
#   ./setup/run.sh          # full setup + run the canonical example
#   SKIP_INSTALL=1 ./setup/run.sh   # skip submodule init + configure/build, just run
# ==============================================================================
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BIN="build/src/surge-xt/surge-xt_artefacts/Release/CLI/surge-xt-cli"

# --- 1. prerequisites -------------------------------------------------------
if [ -z "${SKIP_INSTALL:-}" ]; then
  # Idempotent: `git submodule update --init --recursive` is a no-op if already initialized.
  echo "==> Initializing git submodules (no-op if already done)..."
  git submodule update --init --recursive

  # Idempotent: re-running cmake configure on an existing build/ dir just re-checks the cache.
  echo "==> Configuring CMake (Release, Ninja)..."
  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

  # Idempotent: ninja only rebuilds what changed.
  echo "==> Building surge-xt-cli target only (not the full plugin set)..."
  cmake --build build --target surge-xt-cli -- -j "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

if [ ! -x "$BIN" ]; then
  echo "ERROR: expected binary not found at $BIN" >&2
  exit 1
fi

# --- 2. run the canonical example ------------------------------------------
echo "==> $BIN --version"
"$BIN" --version

echo "==> $BIN --help (first 5 lines)"
"$BIN" --help | head -5

echo "==> $BIN --list-devices --no-stdin"
"$BIN" --list-devices --no-stdin

echo "OK: surge (Surge XT) canonical example completed."
