# surge — setup & canonical example (khaledt-dev)

> Private mirror of `surge-synthesizer/surge`. This folder documents **exactly** how the
> canonical example was brought up on this machine, reproducibly via `./setup/run.sh`.

## What this repo is / what the canonical example does
Surge XT is a free/open-source hybrid synthesizer built on JUCE/CMake, shipped as VST3/AU/CLAP
plugins and a Standalone app. The canonical example for a **smoke** depth is: initialize all git
submodules, configure the CMake+Ninja build, build the lightest meaningful target that proves the
whole native toolchain (JUCE, CLAP, LuaJIT, sst-* DSP libs) actually compiles and links — the
`surge-xt-cli` headless CLI player — and run it with `--version`, `--help`, and `--list-devices`.
This avoids building the full plugin set (VST3/AU/CLAP/Standalone formats), which is far larger
and not needed to prove the toolchain works.

## System it was verified on
- Apple M5 Max, macOS 26.4 arm64 (Darwin). AppleClang 21.0.0 (Xcode 26.6.0).
- CMake 4.4.0, Ninja 1.13.2. No Python/uv involved (pure C++/CMake project).
- Depth reached: **smoke**
- Wall-clock to reproduce: **~3 min** (`git submodule update --init --recursive` ~26s,
  `cmake -B build -G Ninja` configure ~31s incl. building LuaJIT, `cmake --build build --target
  surge-xt-cli -j 18` ~1m30s) · Extra disk used: **~1.0 GB** (`.git` submodule objects ~520 MB +
  `libs/` submodule working trees 238 MB + `build/` 271 MB)

## Prerequisites
- `cmake` (4.4.0 used), `ninja` (1.13.2 used), Xcode command line tools (AppleClang 21.0.0).
- 22 git submodules under `libs/` (JUCE, CLAP, fmt, PEGTL, LuaJIT, the `sst-*` DSP libraries,
  tuning-library, zstd, etc.), initialized recursively — this repo does **not** build without
  them. They were **not** initialized when this repo was cloned/mirrored, so step 1 below is
  required on a fresh clone.
- No Python/uv/vcpkg needed for this depth. `libs/luajitlib/LuaJIT` is built automatically by
  CMake at configure time (a `build-macos-luajit.sh` sub-build), which is included in the ~31s
  configure time above.

## Exact steps performed (copy-paste reproducible)
```bash
cd /Users/km/dev/surge

# 1. Initialize all 22 submodules (recursive — some submodules have their own nested submodules,
#    e.g. libs/clap-juce-extensions/clap-libs/*, libs/simde/test/munit,
#    libs/sst/sst-plugininfra/libs/*). ~26s, adds ~520MB to .git + 238MB of working trees.
git submodule update --init --recursive

# 2. Configure (Release, Ninja). Builds LuaJIT as part of configure. ~31s.
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
# -- Successfully built LuaJIT: /Users/km/dev/surge/build/libs/luajitlib/LuaJIT/bin/...
# -- macOS standalone includes CLI
# -- Adding surge-xt-cli to surge-xt_Packaged
# -- Configuring done (31.0s)
# -- Generating done (0.3s)
# -- Build files have been written to: /Users/km/dev/surge/build

# 3. Build ONLY the surge-xt-cli target (not the full VST3/AU/CLAP/Standalone plugin set).
#    Building this target still compiles the shared "surge-xt" code (JUCE GUI/audio modules,
#    surge-common DSP, CLAP extensions) since surge-xt-cli links against it, but it skips
#    packaging/codesigning the plugin bundles. ~1m30s with -j 18 (615 ninja steps).
cmake --build build --target surge-xt-cli -- -j 18
# [614/615] Linking CXX executable src/surge-xt/surge-xt_artefacts/Release/CLI/surge-xt-cli

# 4. Run it — version + help + list-devices smoke test
BIN=build/src/surge-xt/surge-xt_artefacts/Release/CLI/surge-xt-cli
"$BIN" --version
"$BIN" --help
"$BIN" --list-devices --no-stdin
```

## Expected output
```
$ "$BIN" --version
1.4.khaledt-dev.6d71a289

$ "$BIN" --help
..:: Surge XT CLI - Command Line player for Surge XT ::..
Usage: build/src/surge-xt/surge-xt_artefacts/Release/CLI/surge-xt-cli [OPTIONS]

Options:
  -h,--help                   Print this help message and exit
  --version                   Display program version information and exit
  -l,--list-devices           List all devices available on this system, then quit.
  ...

$ "$BIN" --list-devices --no-stdin
00:36:14.161 - Output Audio Device: [0.0] : CoreAudio.MacBook Pro Speakers
00:36:14.161 - Input Audio Device: [0.0] : CoreAudio.MacBook Pro Microphone
```
All three commands exit 0. `--list-devices` successfully probing real CoreAudio devices confirms
the JUCE audio-devices layer linked and initialized correctly, not just that the binary launches.

## Caveats / boundary
- This is **smoke** depth only: no actual synth audio was rendered (no MIDI-in-to-audio-out
  session was run) and no plugin format (VST3/AU/CLAP/Standalone) was built or validated with
  `pluginval`/`clap-info`. The `surge-xt-cli` binary does support playing a patch against a real
  audio/MIDI device (`--init-patch`, `--all-midi-inputs`, etc.) but that requires an interactive
  audio device session, which is out of scope for smoke depth on this box.
- The full plugin set (`cmake --build build` with no target, or `--target surge-xt-cli-installer`)
  was deliberately **not** built — it links four additional JUCE plugin-format wrappers
  (VST3/AU/CLAP/Standalone) plus packaging/codesigning steps, which is significantly heavier than
  needed to prove the toolchain. Building `surge-xt-cli` alone already forces compilation of the
  full shared "surge-xt" code (JUCE GUI, audio, DSP modules) so it is a meaningful proof the whole
  toolchain (JUCE, CLAP juce extensions, LuaJIT, sst-* DSP libs) compiles and links on this
  machine.
- Next sweep for **best-effort**: build the `Standalone` format (`cmake --build build --target
  "Surge XT_Standalone"`) and drive `surge-xt-cli` with `--init-patch` + a virtual MIDI input to
  render real audio, or build `surge-xt_CLAP` and validate with `clap-info`/`pluginval`.

## Troubleshooting
- No errors were hit. One thing worth knowing in advance: the top-level repo clone (mirror) had
  all 22 submodules **unregistered** (`git submodule status` showed every path prefixed `-`), so
  `cmake -B build` will fail immediately with missing-source-file errors if step 1 is skipped.
- `.git` grows from ~583 MB to ~1.1 GB after submodule init (mostly `libs/JUCE`'s and
  `libs/eurorack/eurorack`'s history) — expected and one-time.
