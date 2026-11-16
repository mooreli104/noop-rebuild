# CLAUDE.md: NOOP rebuild

## What this branch is

`rebuild` is an orphan branch. It shares no history with `main`. The user is rebuilding NOOP
from an empty folder, one small piece at a time, **to understand how every part works**. Shipping
the app comes second. Understanding comes first.

- **Rebuild worktree:** `/home/moore/noop-rebuild` (this folder, branch `rebuild`)
- **Reference worktree:** `/home/moore/noop-strava` (branch `main`, the full original app).
  Treat it as read-only. Never edit it from this session.

NOOP is an offline, on-device companion app for WHOOP straps. It pairs over Bluetooth Low Energy
(BLE), decodes the strap's binary frames, stores them in SQLite, and computes HR, HRV, recovery,
strain and sleep locally. It has no server, no account and no telemetry. That constraint carries
over to the rebuild.

## How to work with the user (most important)

1. **The user writes the code.** Claude explains the concept, proposes the next small step, and
   reviews what the user wrote. Claude writes code only when the user explicitly asks
   ("just write it", "show me"). Even then, keep it to the one step at hand.
2. **One concept per step.** A step is one file or one function plus a test, small enough to
   finish and understand in one sitting. Don't scaffold ahead of where the user is.
3. **Explain why before how.** For each step, cover what problem it solves, where the original
   does it (`../noop-strava/<path>:<line>`), and what the simplest version looks like. Point out
   which parts of the original are later hardening the user can skip for now (perf tweaks,
   diagnostics, 5.0/MG support, Android twins).
4. **Every step ends green.** Each step has a test the user runs (`swift test`), and Claude
   confirms the actual output before calling the step done.
5. **Don't copy the original wholesale.** Read it, explain it, then help the user write a
   simpler version. Copying exact constants (a CRC table, field offsets) is fine, and so is
   verifying against the original's fixtures. Those are facts, not things to re-derive.
6. **Keep the progress log at the bottom of this file up to date.** It's the shared memory
   between sessions. At the end of each step, add a line naming what was built and what was learned.
7. Commit only when the user asks. Use small commits with one step each.

## Environment (as of 2026-11-02)

- WSL2 Ubuntu on x86-64. **Swift is not installed yet**: Step 0 installs it.
- JDK 21 is present. Android (Kotlin) comes much later, if at all.
- No Xcode on Linux, so the macOS/iOS app layers can't be built here. That's fine: everything
  through step 8 below is pure Swift and runs under `swift test` on Linux.

## The roadmap: bottom of the stack first

Each layer depends only on the ones above it in this list. The original's equivalent location
is in brackets.

### Phase 1: Bytes (`WhoopProtocol`) [`../noop-strava/Packages/WhoopProtocol`]

**Step 0: Toolchain.** Install a swift.org toolchain (≥ 5.9, a 6.x release is fine), plus
`build-essential libc6-dev libncurses-dev libxml2 libcurl4 zlib1g-dev libedit2 pkg-config unzip`.
Check it with `swift --version`.
*Learn:* SwiftPM is Swift's build tool and package manager, like Cargo or npm.

**Step 1: The first file, `Packages/WhoopProtocol/Package.swift`.** Declare one library target
`WhoopProtocol` and one test target `WhoopProtocolTests`. Create
`Sources/WhoopProtocol/` and `Tests/WhoopProtocolTests/` with one trivial function and one
trivial test. Run `swift build && swift test`.
*Learn:* the package manifest, targets, the `Sources`/`Tests` convention, and XCTest.
*Reference:* `../noop-strava/Packages/WhoopProtocol/Package.swift`. Ignore its executables and
resources for now.

**Step 2: CRC-8, the first real function.** Write `Sources/WhoopProtocol/Framing.swift` with
`crc8(_ bytes: [UInt8]) -> UInt8` (polynomial 0x07). Start with the bit-by-bit loop. Then
optionally move to the 256-entry lookup table the original uses.
*Learn:* what a checksum is, why BLE data needs one, and bit operations in Swift (`^`, `<<`,
`&`, overflow behaviour of `UInt8`).
*Test:* known vectors (`crc8([]) == 0`, plus the standard "123456789" check value 0xF4).
*Reference:* `Framing.swift:1-35`.

**Step 3: CRC-32.** Write `crc32` (zlib, reflected, polynomial 0xEDB88320, init/xorout 0xFFFFFFFF).
*Test:* "123456789" gives 0xCBF43926.
*Reference:* `Framing.swift:38-62`. Skip `crc16Modbus` until WHOOP 5.0 support.

**Step 4: The WHOOP 4.0 frame envelope.** The frame layout is
`[0xAA SOF][len u16 LE][crc8 of len][type][seq][cmd][payload…][crc32 u32 LE]`.
Write `verifyFrame(_:) -> Bool` first. Then make it return a reason enum (`noStartOfFrame`,
`lengthMismatch`, `headerChecksumMismatch`, `payloadCRCMismatch`).
*Learn:* little-endian, slicing, and validating untrusted input before reading any fields.
*Test:* real frames from `../noop-strava/Packages/WhoopProtocol/Tests/WhoopProtocolTests/Resources/frames.json`
and `frame_integrity_oracle.json`.
*Reference:* `Framing.swift:83-280` (`FrameRejectReason`, `FrameLimits`, `verifyFrame`).

**Step 5: Reassembly.** BLE delivers frames in fragments (notifications of roughly 20 to 244 bytes).
Write a small `FrameAssembler` with `feed(_ fragment:) -> [[UInt8]]` that returns complete frames.
*Reference:* `Framing.swift:~340-470`.

**Step 6: Decoding a packet: live heart rate.** Hand-decode `REALTIME_DATA` (type 40):
timestamp u32 @6, subseconds u16 @10, heart_rate u8 @12, rr_count u8 @13, then RR intervals.
Return a plain `struct RealtimeHR`.
*Learn:* turning bytes into typed values. This is the first point where the strap "says" something.
*Reference:* the `REALTIME_DATA` entry in `Sources/WhoopProtocol/Resources/whoop_protocol.json`,
and `PostHooks.swift`.

**Step 7: Schema-driven decoding (optional, later).** The original doesn't hand-write decoders.
It loads `whoop_protocol.json` and interprets it (`Schema.swift`, `Interpreter.swift`). Only do
this once hand-decoding two or three packet types makes the repetition obvious.

**Step 8: A CLI, `whoop-decode`.** An executable target that reads a hex frame and prints the
decoded fields. It's the first thing the user can actually run.
*Reference:* `Sources/whoop-decode/main.swift`.

### Phase 2: Math (`StrandAnalytics`) [`../noop-strava/Packages/StrandAnalytics`]
HRV (RMSSD from RR intervals), then resting HR, then strain, then recovery, then sleep staging.
Pure functions over arrays, each with a test. Plan this in detail when Phase 1 is done.

### Phase 3: Storage (`WhoopStore`) [`../noop-strava/Packages/WhoopStore`]
GRDB/SQLite: the first table, the first migration, then writing decoded samples. On Linux this needs
the SQLite setup in `../noop-strava/docs/BUILD.md`.

### Phase 4: Transport (BLE)
Real Bluetooth. This needs macOS/iOS (CoreBluetooth) or Android, and a real strap. Before writing
any BLE code, read the BLE safety contract in `../noop-strava/docs/CONTRIBUTING.md`. **Never send
destructive commands** (firmware/DFU, ship-mode, power-cycle, data trim).

### Phase 5: App UI
SwiftUI on macOS/iOS, or Compose on Android.

## Conventions carried over from the original

- `Packages/` code is pure: never `import UIKit`, `AppKit` or `CoreBluetooth` there. That's what
  lets it build and test on Linux.
- Inbound frames are CRC-checked before anything reads their fields.
- No hardcoded hex frames in app code. Protocol facts live in the decoder or schema.
- The full rules are in `../noop-strava/AGENTS.md`. Most of them (Android parity, CI, release
  process) don't apply until much later. Bring each one in only when the rebuild reaches the
  layer it governs.

## Progress log

<!-- One line per finished step: date, step, what was built, the key thing learned. -->
- 2026-11-02: Branch created (orphan `rebuild`, worktree `../noop-rebuild`). Next: Step 0.
- 2026-11-12: **Step 0 done.** Installed Swift 6.4.2 via swiftly (`~/.local/share/swiftly`), plus
  `libncurses-dev` and `unzip`. Learned: a toolchain = compiler + stdlib + Foundation + XCTest +
  SwiftPM; swiftly manages versions like rustup. On Ubuntu 24.04, `libcurl4` is named `libcurl4t64`.
  Next: Step 1.
- 2026-11-12: **Step 1 done.** `Packages/WhoopProtocol` builds and `swift test` is green (1 XCTest).
  Learned: `swift-tools-version` comment, `.target` / `.testTarget` + `dependencies`, the
  `Sources/<Target>` and `Tests/<Target>` convention, `public` across modules, `@testable import`,
  XCTest discovery (`test` prefix). `.build/` is gitignored. Next: Step 2 (CRC-8).
- 2026-11-16: **Step 2 done.** `crc8` (bit-by-bit, poly 0x07) in `Framing.swift`; 3 tests green
  (`[]`→0, `"1"`→0x97, `"123456789"`→0xF4). Learned: a CRC is the remainder of polynomial division
  over GF(2), where XOR plays the role of subtraction; `UInt8 <<` drops the high bit; the lookup table is
  just the 8 inner steps precomputed per byte value. Next: Step 3 (CRC-32).
