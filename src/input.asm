; =============================================================================
;   input.asm — LightCycles input shim using 6502-Lib polling
; =============================================================================
;   Joystick-first, keyboard-fallback: PollInput (P1) and PollInputP2 each
;   poll their own joystick port via 6502-Lib's PollJoy1/PollJoy2, and fall
;   back to this tick's already-drained keyboard split (WASD=P1, arrows=P2)
;   only when that player's joystick shows no direction at all this poll
;   (including when no GPIO card is fitted). DrainKeyboardSplit is called
;   exactly once per tick, from PollInput (which runs first in MainLoop),
;   so PollInputP2 reuses the same drain window's KB_DIR_P2 result instead
;   of re-draining an already-empty Chrin buffer.
;
;   A bike always advances forward every tick regardless of input — turning
;   is a discrete heading change, not something that needs to be held to
;   keep moving — so unlike Pong's paddles, no hold/decay layer is needed
;   here: DrainKeyboardSplit's per-tick "last direction seen" result is the
;   same sticky-until-changed semantics the joystick-only code already had.
; =============================================================================

.include "../../6502-Lib/include/input.inc"
.include "../../6502-Lib/core/input.asm"

; -----------------------------------------------------------------------------
; PollInput — P1: joystick 1 first, WASD fallback when idle. Also drains
; the keyboard (once, for both players) and ORs joystick A / space into
; START_PRESSED, independent of the direction priority.
; -----------------------------------------------------------------------------
PollInput:
	stz START_PRESSED

	jsr PollJoy1
	jsr DrainKeyboardSplit

	lda JOY_STATE
	and #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
	cmp #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
	beq @kbDir                ; joystick idle on all 4 directions -> fallback

	lda JOY_STATE
	and #JOY_UP
	bne @jNotUp
	lda #DIR_UP
	sta NEXT_DIR
@jNotUp:
	lda JOY_STATE
	and #JOY_DOWN
	bne @jNotDown
	lda #DIR_DOWN
	sta NEXT_DIR
@jNotDown:
	lda JOY_STATE
	and #JOY_LEFT
	bne @jNotLeft
	lda #DIR_LEFT
	sta NEXT_DIR
@jNotLeft:
	lda JOY_STATE
	and #JOY_RIGHT
	bne @jNotRight
	lda #DIR_RIGHT
	sta NEXT_DIR
@jNotRight:
	jmp @doneDir

@kbDir:
	lda KB_DIR_P1
	cmp #KB_DIR_NONE
	beq @doneDir
	sta NEXT_DIR
@doneDir:

	; Fire/A: OR'd independently of direction priority — joystick A held
	; OR keyboard space seen this drain, either sets START_PRESSED.
	lda JOY_STATE
	and #JOY_A
	bne @checkKbFire
	lda #1
	sta START_PRESSED
	jmp @doneFire
@checkKbFire:
	lda KB_FIRE
	beq @doneFire
	lda #1
	sta START_PRESSED
@doneFire:

	lda #$00
	sta FIRE_EDGE
	lda PREV_FIRE
	bne @noEdge
	lda START_PRESSED
	beq @noEdge
	inc FIRE_EDGE
@noEdge:
	lda START_PRESSED
	sta PREV_FIRE
	rts

; -----------------------------------------------------------------------------
; PollInputP2 — P2: joystick 2 first, arrow-key fallback when idle. Always
; polled, regardless of GAME_MODE -- this used to be gated on
; GAME_MODE == MODE_2P (skip reading a controller nothing in 1P mode would
; use), but that gate ran on the title screen too, where GAME_MODE reflects
; whichever mode happens to be currently selected rather than "are we
; actually playing 1P". With 1P as the default, that meant JOY_STATE2 was
; never written at all while sitting on the title screen -- left at
; whatever garbage was in RAM at boot ($00, which reads as every direction
; held at once) -- and SetModeFromInput/HandleColorPicker read that as a
; real button press, silently flipping GAME_MODE the instant the title
; screen loaded. Safe to always poll: during actual 1P gameplay,
; ComputeP2AIDirection unconditionally overwrites P2_NEXT_DIR right after
; this runs, on every one of its exit paths, so whatever a real (or
; absent) P2 controller reports here never survives to affect anything.
; Reuses KB_DIR_P2 from the DrainKeyboardSplit call PollInput already made
; this tick.
; -----------------------------------------------------------------------------
PollInputP2:
	jsr PollJoy2

	lda JOY_STATE2
	and #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
	cmp #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
	beq @kbDir                ; joystick idle on all 4 directions -> fallback

	lda JOY_STATE2
	and #JOY_UP
	bne @notUp
	lda #DIR_UP
	sta P2_NEXT_DIR
@notUp:
	lda JOY_STATE2
	and #JOY_DOWN
	bne @notDown
	lda #DIR_DOWN
	sta P2_NEXT_DIR
@notDown:
	lda JOY_STATE2
	and #JOY_LEFT
	bne @notLeft
	lda #DIR_LEFT
	sta P2_NEXT_DIR
@notLeft:
	lda JOY_STATE2
	and #JOY_RIGHT
	bne @done
	lda #DIR_RIGHT
	sta P2_NEXT_DIR
	rts

@kbDir:
	lda KB_DIR_P2
	cmp #KB_DIR_NONE
	beq @done
	sta P2_NEXT_DIR
@done:
	rts
