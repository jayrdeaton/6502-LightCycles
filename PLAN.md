# Plan: Ship 6502 LightCycles MVP then Expand

## Goal
Deliver a deterministic, cell-based Tron-style LightCycles cartridge for the 6502 platform, with two-player support first and optional one-player AI as a follow-up.

## Scope
- Two-player mode is first-class.
- One-player AI is secondary and may land in MVP plus one.
- Keep implementation aligned with proven Snake and Pong patterns.

## Coworker Spec Constraints
- Core loop remains simple and deterministic:
  - read input
  - resolve turns
  - advance one cell
  - collision check
  - commit trails
  - wait for next tick
- Collision outcomes are authoritative and minimal:
  - wall collision
  - occupied-cell collision
- Start with TMS9918 Graphics I constraints before experimenting with denser logical grids.

## Platform Guardrails
- Preserve joystick-first controls and avoid keyboard fallback unless intentionally changed later.
- Keep VDP multi-byte writes interrupt-safe.
- Keep GPIO and RTC hardware checks explicit where needed.
- Prefer occupancy-grid collision model for predictable debugging and deterministic replay.

## Phase 0: Repository Bootstrap
1. Create initial structure:
   - src
   - assets or data (optional)
   - docs (optional)
2. Add files:
   - entrypoint assembly file
   - linker config
   - Makefile
   - README
   - BUGS log template

## Phase 1: Core Game Architecture
1. Define constants and memory map:
   - arena bounds
   - direction enum
   - player state fields: x, y, direction, alive, score
   - trail occupancy storage
2. Define game states:
   - title
   - mode select
   - playing
   - paused
   - round over
   - match over
3. Define deterministic rules for simultaneous movement and collisions.

## Phase 2: Main Loop and Input
1. Implement mode select flow for 1P and 2P.
2. Implement per-tick loop:
   - poll both players
   - resolve turn intents
   - compute next cells
   - resolve collisions
   - commit trail writes
   - update scores and state
3. Keep 2P routing behavior consistent with Pong split-controller handling.

## Phase 3: Rendering and HUD
1. Draw arena border and initial spawn markers.
2. Draw trail tiles/colors per player.
3. Render HUD labels and scores with tile text helpers.
4. Implement game-over and restart overlays.

## Phase 4: Optional MVP Plus One AI
1. Add simple local AI heuristic for one-player mode:
   - continue straight if safe
   - otherwise choose safer turn by local occupancy sampling
2. Keep AI deterministic under fixed seed when possible.

## Verification Gates
1. Build completes with no assembler or linker errors.
2. Manual gameplay checks:
   - independent 2P controls
   - correct wall collision handling
   - reliable trail collision handling in long rounds
   - documented simultaneous-collision outcomes
3. Determinism check with fixed seed and repeated input sequence.
4. Tick cadence remains stable without visible rendering corruption.

## Source References
- /Users/jay/Developer/6502-Snake/Snake.asm
- /Users/jay/Developer/6502-Snake/src/game.asm
- /Users/jay/Developer/6502-Snake/src/vdp.asm
- /Users/jay/Developer/6502-Snake/src/input.asm
- /Users/jay/Developer/6502-Snake/src/rng.asm
- /Users/jay/Developer/6502-Snake/src/zeropage.inc
- /Users/jay/Developer/6502-Pong/src/input.asm
- /Users/jay/Developer/6502-Pong/src/screens.asm
- /Users/jay/Developer/6502-Pong/src/physics.asm

## Definition of Done
- A playable LightCycles cartridge exists with stable two-player gameplay and deterministic collision behavior.
- Plan documents and build scripts are sufficient to continue implementation without rediscovery.
