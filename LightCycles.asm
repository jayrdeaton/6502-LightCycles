; =============================================================================
;   LightCycles.asm - cartridge entry point and main loop skeleton
; =============================================================================

.setcpu "65C02"

.include "6502.inc"
.include "src/zeropage.inc"
.include "src/tiles.asm"
.include "src/vdp.asm"
.include "src/font.asm"
.include "src/rng.asm"
.include "src/input.asm"
.include "src/sound.asm"
.include "src/game.asm"

.segment "CART"

GAME_SPEED_LO = 8
GAME_SPEED_HI = 0

CartReset:
  ldx #$ff
  txs                             ; KernalInit does not reset the stack
  jsr KernalInit                  ; pointer or enable interrupts itself --
  cli                              ; every sibling cartridge in this family
                                    ; does both here, and skipping them left
                                    ; the IRQ-driven keyboard scanner (and
                                    ; anything else interrupt-driven) dead

  lda #0
  jsr SetIOMode                   ; video/local keyboard, so Chrin (used by
                                    ; the joystick-first keyboard fallback,
                                    ; including on the title screen, before
                                    ; StartRound's own SetIOMode call would
                                    ; otherwise be the first one) reads from
                                    ; the right source from the very start

  jsr InitVideo
  jsr InitGraphicsI
  jsr NewGame

MainLoop:
  jsr PollInput
  jsr PollInputP2
  jsr Tick
  lda #GAME_SPEED_LO
  ldx #GAME_SPEED_HI
  jsr SysDelay
  jmp MainLoop

; Dispatch through the RAM vectors KernalInit points at the Kernal's own
; default handlers (keyboard scanning included) -- a bare `rti` here, as
; this cartridge had before, means the IRQ-driven keyboard scanner (and
; anything else interrupt-driven) never runs at all, regardless of cli.
IrqTrampoline:
  jmp (IRQ_PTR)

NmiTrampoline:
  jmp (NMI_PTR)

.segment "VECTORS"
.word NmiTrampoline
.word CartReset
.word IrqTrampoline
