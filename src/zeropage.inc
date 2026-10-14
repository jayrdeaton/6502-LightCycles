; =============================================================================
;   zeropage.inc - initial zero-page layout for LightCycles
; =============================================================================

STATE_TITLE     = 0
STATE_PLAYING   = 1
STATE_ROUNDOVER = 2
STATE_GAMEOVER  = 3
STATE_PAUSED    = 4

DIR_UP          = 0
DIR_DOWN        = 1
DIR_LEFT        = 2
DIR_RIGHT       = 3

MODE_1P         = 0
MODE_2P         = 1

GAME_STATE      := $3A
GAME_MODE       := $3B
RNG_STATE       := $3C
TICK_COUNTER    := $3D
JOY_STATE       := $3E
PREV_FIRE       := $3F
START_PRESSED   := $4C
FIRE_EDGE       := $4D

P1_X            := $40
P1_Y            := $41
P1_DIR          := $42
P1_NEXT_DIR     := $43
P1_ALIVE        := $44
NEXT_DIR        := P1_NEXT_DIR

P2_X            := $45
P2_Y            := $46
P2_DIR          := $47
P2_NEXT_DIR     := $48
P2_ALIVE        := $49

P1_SCORE        := $4A
P2_SCORE        := $4B

JOY_STATE2      := $4F

OFFSET_LO       := $50
OFFSET_HI       := $51
WORK_PTR        := $52
STR_IDX         := $54
SCAN_TMP        := $55
P1_NEXT_X       := $56
P1_NEXT_Y       := $57
P2_NEXT_X       := $58
P2_NEXT_Y       := $59
AI_DIR_TMP      := $5A
AI_TEST_X       := $5B
AI_TEST_Y       := $5C
HUD_COL         := $5D
MSG_ROW         := $5E
NUM_TMP         := $5F
DIGIT_TMP       := $60
ROUND_RESULT    := $61
P1_COLOR_IDX    := $62
P2_COLOR_IDX    := $63
P1_TRAIL_COLOR  := $64
P2_TRAIL_COLOR  := $65
MENU_P1_PREV    := $66
MENU_P2_PREV    := $67

KB_DIR_P1       := $68   ; DrainKeyboardSplit output: WASD direction (P1)
KB_DIR_P2       := $69   ; DrainKeyboardSplit output: arrow-key direction (P2)
KB_FIRE         := $6A   ; DrainKeyboardSplit output: 1 if either fire key seen
                          ; this call - the byte LightCycles actually reads,
                          ; since START/pause is one shared action here, not
                          ; per-player
PICKER_TMP      := $6B   ; HandleColorPicker scratch: effective LEFT/RIGHT byte
KB_DIR          := $6C   ; unused output of DrainKeyboardCombined - LightCycles
                          ; calls DrainKeyboardSplit, not Combined, but the
                          ; library assembles as one unit so KB_DIR must still
                          ; resolve to something
KB_FIRE_P1      := $6D   ; DrainKeyboardSplit output: space seen this call.
                          ; Unused by LightCycles (no per-player fire action)
                          ; but must resolve to something for the same reason
                          ; as KB_DIR above.
KB_FIRE_P2      := $6E   ; DrainKeyboardSplit output: enter seen this call.
                          ; Unused by LightCycles, same reason as KB_FIRE_P1.

; --- Bitmap-mode text renderer (src/font.asm, DrawChar/DrawText in vdp.asm) ---
TEXT_ROW        := $6F   ; caller-set: top-left Y pixel origin
TEXT_COL        := $70   ; caller-set: top-left X pixel origin (DrawText
                          ; advances this past each character it draws)
TEXT_COLOR      := $71   ; caller-set: TMS_* color for the glyph's pixels
FONT_PTR        := $72   ; 2 bytes, $72-$73: scratch pointer into FontData
FONT_TMP        := $74   ; scratch: char*5 multiply, then each glyph column's
                          ; row-bits (bit0=top row .. bit6=bottom row)
TEXT_ROW_I      := $75   ; scratch: glyph row loop counter, 0-6
TEXT_COL_I      := $76   ; scratch: glyph column loop counter, 0-4
SCAN_TMP2       := $77   ; scratch: second loop counter (DrawColorSwatch's
                          ; origin col; SCAN_TMP alone was already taken)
FONT_HI         := $7A   ; scratch: overflow bit (0 or 1) from DrawChar's
                          ; index*5 multiply, propagated into FONT_PTR's
                          ; high byte -- (char-$20)*5 can reach 290, past
                          ; what one 8-bit add tracks by itself
TEXT_STR_PTR    := $78   ; 2 bytes, $78-$79: DrawText's string pointer --
                          ; deliberately NOT WORK_PTR, since DrawChar calls
                          ; down into PixelSet/ComputePixelAddress, which
                          ; clobbers WORK_PTR for its own shadow-buffer
                          ; addressing on every single pixel plotted

; DrawModeLine/DrawColorLines run every tick on the title screen, but
; should only erase-and-redraw when the value actually changed -- doing
; it unconditionally every tick flickers, since each redraw has to erase
; first (PixelSet only ever turns pixels on). $FF is an impossible value
; for any of these (GAME_MODE is 0/1, a color index is 0-6), so
; DrawTitleScreen resets them to $FF on a fresh entry to force that
; first draw regardless of what the mode/colors happened to be last time.
LAST_GAME_MODE   := $7B
LAST_P1_COLOR_IDX := $7C
LAST_P2_COLOR_IDX := $7D

; SetModeFromInput debounce: MODE now toggles on an UP/DOWN edge (either
; player) instead of a fixed up=1P/down=2P mapping, so it needs the same
; "already acted on this press, wait for release" latch MENU_P1_PREV/
; MENU_P2_PREV use for the color pickers.
MENU_MODE_PREV  := $80

; ComputeP2AIDirection scratch: which perpendicular direction currently
; closes the distance to P1 (DIR_UP/DOWN/LEFT/RIGHT), or $FF if P1 is
; exactly level on the axis that matters (no preference).
AI_PREFERRED_DIR := $81

BITMAP_BUF      = $2000
COLOR_BUF       = $3800

; Per-pixel trail ownership, decoupled from the VDP's own color table --
; see PixelSetP1Trail/PixelSetP2Trail in vdp.asm for why. Same 6144-byte,
; 1-bit-per-pixel layout as BITMAP_BUF, just two separate planes (one per
; player) instead of one.
P1_OWN_BUF      = $5000
P2_OWN_BUF      = $6800
