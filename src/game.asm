; =============================================================================
;   game.asm - pixel-precision LightCycles game loop
; =============================================================================

.segment "CART"

NewGame:
  lda #MODE_1P
  sta GAME_MODE
  lda #4                    ; TrailFgColorTable[4] = LT_BLUE
  sta P1_COLOR_IDX
  lda #1                    ; TrailFgColorTable[1] = LT_YELLOW
  sta P2_COLOR_IDX
  stz MENU_P1_PREV
  stz MENU_P2_PREV
  stz MENU_MODE_PREV
  jsr ApplySelectedTrailColors
  lda #$2A
  sta RNG_STATE
  jsr DrawTitleScreen
  rts

Tick:
  lda GAME_STATE
  cmp #STATE_TITLE
  bne :+
  jmp TickTitle
:
  cmp #STATE_PLAYING
  bne :+
  jmp TickPlaying
:
  cmp #STATE_PAUSED
  bne :+
  jmp TickPaused
:
  cmp #STATE_GAMEOVER
  bne :+
  jmp TickGameOver
:
  jmp TickDone

TickTitle:
  jsr HandleColorPicker
  jsr SetModeFromInput
  jsr DrawModeLine
  jsr DrawColorLines
  lda FIRE_EDGE
  bne :+
  jmp TickDone
:
  jsr StartRound
  rts

TickGameOver:
  lda FIRE_EDGE
  bne :+
  jmp TickDone
:
  jsr DrawTitleScreen
  rts

TickPaused:
  lda FIRE_EDGE
  bne :+
  jmp TickDone
:
  lda #STATE_PLAYING
  sta GAME_STATE
  rts

TickPlaying:
  lda FIRE_EDGE
  beq @playAdvance
  lda #STATE_PAUSED
  sta GAME_STATE
  rts

@playAdvance:
  lda GAME_MODE
  cmp #MODE_1P
  bne @skipAi
  jsr ComputeP2AIDirection
@skipAi:

  jsr ApplyRequestedTurns

  jsr ComputeNextPositions

  lda P1_NEXT_X
  cmp P2_NEXT_X
  bne @notHeadOn
  lda P1_NEXT_Y
  cmp P2_NEXT_Y
  bne @notHeadOn
  stz P1_ALIVE
  stz P2_ALIVE
  jmp ResolveRound

; Collision is purely "is this pixel's bit already set" (PixelIsSet) --
; it used to also require PixelColorCompatible (the target's TMS9918
; color-table byte being empty or already this player's color) before
; ruling a move safe. That byte is shared by all 8 horizontal pixels on
; a scanline, not just the one being tested, so an entirely untouched
; pixel could still read "incompatible" -- and therefore die -- just for
; sitting in the same 8-pixel group as an unrelated, different-colored
; trail a few columns away with nothing actually touching. Confirmed via
; the debugger: PixelIsSet(50,99)=clear (genuinely empty) yet
; PixelColorCompatible(50,99, a second color) still reported incompatible
; after only column 96 -- same group, different pixel -- had been drawn.
@notHeadOn:
  lda P1_NEXT_Y
  cmp #192
  bcs P1CollisionDead
  ldx P1_NEXT_X
  jsr PixelIsSet
  beq P1CollisionClear
P1CollisionDead:
  stz P1_ALIVE
P1CollisionClear:

  lda P2_NEXT_Y
  cmp #192
  bcs P2CollisionDead
  ldx P2_NEXT_X
  jsr PixelIsSet
  beq P2CollisionClear
P2CollisionDead:
  stz P2_ALIVE
P2CollisionClear:

ResolveRound:
  lda P1_ALIVE
  beq ResolveP1Dead
  lda P2_ALIVE
  beq ResolveP2DeadOnly

  jsr CommitP1Move
  jsr CommitP2Move
  jsr UpdateHeadSprites
  rts

ResolveP1Dead:
  lda P2_ALIVE
  beq ResolveBothDead
  lda #2                   ; P1 crashed -> P2 wins (ROUND_RESULT names the
  sta ROUND_RESULT           ; WINNER, not who died -- this was backwards
                              ; before: P1 dying set ROUND_RESULT=1, which
                              ; DrawGameOverScreen reads as "P1 wins"
  lda #STATE_GAMEOVER
  sta GAME_STATE
  jsr Beep
  jsr DrawGameOverScreen
  rts

ResolveP2DeadOnly:
  lda #1                   ; P2 crashed -> P1 wins
  sta ROUND_RESULT
  lda #STATE_GAMEOVER
  sta GAME_STATE
  jsr Beep
  jsr DrawGameOverScreen
  rts

ResolveBothDead:
  lda #3
  sta ROUND_RESULT
  lda #STATE_GAMEOVER
  sta GAME_STATE
  jsr Beep
  jsr DrawGameOverScreen

TickDone:
  rts

StartRound:
  lda #0
  jsr SetIOMode
  jsr InitGraphicsI
  jsr ClearScreen
  jsr DrawBorder

  stz ROUND_RESULT

  lda #64
  sta P1_X
  lda #96
  sta P1_Y
  lda #DIR_RIGHT
  sta P1_DIR
  sta P1_NEXT_DIR
  lda #$01
  sta P1_ALIVE

  lda #191
  sta P2_X
  lda #96
  sta P2_Y
  lda #DIR_LEFT
  sta P2_DIR
  sta P2_NEXT_DIR
  lda #$01
  sta P2_ALIVE

  lda P1_Y
  ldx P1_X
  jsr PixelSetP1Trail

  lda P2_Y
  ldx P2_X
  jsr PixelSetP2Trail

  lda #STATE_PLAYING
  sta GAME_STATE
  jsr UpdateHeadSprites
  rts

; -----------------------------------------------------------------------------
; DrawTitleScreen - always a full wipe and fresh redraw in the same bitmap
; mode gameplay uses (never a mode switch into the Kernal's separate text
; console), since that mode-switch round trip is exactly what made the old
; text-mode title/win screens unreliable: InitVideo resets the color scheme
; out from under whatever was on screen, and VideoClear did not reliably
; clear content reached from bitmap mode. Reached both at initial boot
; (over an already-blank bitmap) and after a game over (over the live,
; frozen final trail state under the win overlay) -- wiping only at one of
; those call sites would leave the other showing stale content underneath.
; -----------------------------------------------------------------------------
DrawTitleScreen:
  jsr ClearScreen
  jsr DrawBorder

  ; Hide both head sprites -- ClearScreen only wipes the bitmap/color
  ; planes, not the separate hardware sprite layer. A round that ends in
  ; a crash never gets to UpdateHeadSprites's "both alive" branch (see
  ; ResolveRound), so a dead player's sprite is left frozen at its last
  ; position instead of being hidden, and stays visible straight through
  ; the game-over screen and onto this title screen too, since nothing
  ; else ever touches the sprite attribute table on this path.
  jsr InitHeadSprites

  lda #58
  sta TEXT_ROW
  lda #56
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  lda #<TitleLine1
  sta TEXT_STR_PTR
  lda #>TitleLine1
  sta TEXT_STR_PTR+1
  jsr DrawTextBig

  jsr DrawTitleDecoration

  ; Static labels that never change while the title screen is up, drawn
  ; once here rather than every tick from DrawModeLine/DrawColorLines --
  ; those two only need to erase-and-redraw the parts that actually
  ; change (the 1P/2P suffix, the two color swatches). MODE and the color
  ; pickers come before "A START" -- you set these up, then confirm.
  lda #88
  sta TEXT_ROW
  lda #104
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  lda #<ModeLabel
  sta TEXT_STR_PTR
  lda #>ModeLabel
  sta TEXT_STR_PTR+1
  jsr DrawText

  ; Up/down triangles flanking the MODE value -- unlike the color
  ; swatches' left/right chevrons, MODE is an up/down control, so it gets
  ; a shape that actually points the right way instead of reusing </>
  ; sideways (which wouldn't read as "up/down" to anyone looking at it).
  ; The value string is " 1P"/" 2P" (a blank leading cell, then the
  ; digit, then P) starting at TEXT_COL 136 (see DrawModeLine for why not
  ; 134), so the actual ink -- the digit+P pair -- spans pixel columns
  ; 142-152, centered on 147; the triangle is 5px wide, so its left edge
  ; belongs at 147-2=145, not centered over just the leading digit's cell.
  lda #83
  ldx #145
  ldy #TMS_WHITE
  jsr DrawUpTriangle
  lda #97
  ldx #145
  ldy #TMS_WHITE
  jsr DrawDownTriangle

  lda #105
  sta TEXT_ROW
  lda #107
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  lda #<P1ColorLabel
  sta TEXT_STR_PTR
  lda #>P1ColorLabel
  sta TEXT_STR_PTR+1
  jsr DrawText

  ; Left/right triangles flanking the swatch -- custom shapes matching
  ; the up/down triangles' style, rather than the font's thin </> glyphs.
  ; The swatch is 7px (matching the font's glyph height) starting at the
  ; same row as the "P1:" label text (105), so with the triangle at 5px
  ; both are odd-sized and +1 row down from the swatch's top lands the
  ; triangle exactly centered on it -- no more rounding compromise.
  ; Columns stay 2px clear of the swatch on each side (left triangle's
  ; right edge at 133, right triangle's left edge at 145) so the swatch
  ; reads as centered between them.
  lda #106
  ldx #131
  ldy #TMS_WHITE
  jsr DrawLeftTriangle
  lda #106
  ldx #145
  ldy #TMS_WHITE
  jsr DrawRightTriangle

  lda #116
  sta TEXT_ROW
  lda #107
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  lda #<P2ColorLabel
  sta TEXT_STR_PTR
  lda #>P2ColorLabel
  sta TEXT_STR_PTR+1
  jsr DrawText

  lda #117
  ldx #131
  ldy #TMS_WHITE
  jsr DrawLeftTriangle
  lda #117
  ldx #145
  ldy #TMS_WHITE
  jsr DrawRightTriangle

  lda #133
  sta TEXT_ROW
  lda #107
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  lda #<TitleLine4
  sta TEXT_STR_PTR
  lda #>TitleLine4
  sta TEXT_STR_PTR+1
  jsr DrawText

  ; Force the first DrawModeLine/DrawColorLines call below to actually
  ; draw, regardless of whether GAME_MODE/the color indices happen to
  ; match whatever they were the last time the title screen was up.
  lda #$FF
  sta LAST_GAME_MODE
  sta LAST_P1_COLOR_IDX
  sta LAST_P2_COLOR_IDX

  jsr DrawModeLine
  jsr DrawColorLines

  lda #STATE_TITLE
  sta GAME_STATE
  rts

; -----------------------------------------------------------------------------
; DrawTitleDecoration - the title underlined in each player's trail color:
; "LIGHT" in P1's, "CYCLES" in P2's, so the title screen reads as the same
; game rather than a bolted-on splash, right from the two-word split the
; name already has. Split into DrawP1Underline/DrawP2Underline (rather than
; one inline pass) so DrawColorLines can also call just one of them to
; live-update a line the instant that player's color changes, reusing its
; existing per-player change-tracking instead of a separate copy of it here.
; -----------------------------------------------------------------------------
DrawTitleDecoration:
  jsr DrawP1Underline
  jmp DrawP2Underline

; -----------------------------------------------------------------------------
; DrawP1Underline - erases and redraws the underline beneath "LIGHT" (row
; 74) in P1's trail color, with a single white lead pixel at its rightmost
; end, closest to P2's line, so the two read as racing toward each other
; across the gap between the words. White outright, not a brighter tint of
; the trail color -- a picked color's "bright" tier (used by the head
; sprites) is sometimes identical to its own trail color (light blue/light
; yellow have no brighter tier above them), which made the lead invisible
; for those picks.
; It's one real pixel, not a wider block -- the TMS9918's Graphics II color
; table is one color per 8 horizontal pixels per scanline (the same
; granularity that caused the MODE colon to render invisible earlier), so a
; pixel can only carry a color different from its neighbors' if it's the
; only thing touched in its 8-pixel-aligned byte. Column 112 is the first
; pixel of such a byte, right after the body's last byte-aligned column
; (111), so the body shrinks 1px (to end at 111 instead of 113) to land
; exactly there -- no gap, no color collision.
; Must erase first, not just redraw over the old pixels -- PixelSet only
; ever turns bits on, and a color byte already claimed by the old color
; won't take a new one without an explicit clear first.
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, TEXT_COLOR, TEXT_ROW_I, TEXT_COL_I,
;   plus everything PixelSet/PixelClear clobber
; -----------------------------------------------------------------------------
DrawP1Underline:
  lda #1
  sta TEXT_ROW_I
  lda #57
  sta TEXT_COL_I
  lda #74
  ldx #56
  jsr EraseRect

  ldy P1_TRAIL_COLOR
  sty TEXT_COLOR
  stz TEXT_COL_I
@bodyLoop:
  lda TEXT_COL_I
  clc
  adc #56
  tax
  lda #74
  ldy TEXT_COLOR
  jsr PixelSet
  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp #56                     ; body is cols 56-111 (56px, an exact run of
  bne @bodyLoop                ; 7 color bytes); the lead pixel is at 112

  lda #74
  ldx #112
  ldy #TMS_WHITE
  jsr PixelSet
  rts

; -----------------------------------------------------------------------------
; DrawP2Underline - same idea as DrawP1Underline, for the line beneath
; "CYCLES" (row 74) in P2's trail color. Its white lead pixel is at the
; LEFTMOST end instead -- P2's line faces P1's across the gap, so the lead
; has to point the other way for the two to race toward each other rather
; than both pointing right.
; Column 128, the body's natural left edge, is ALREADY the first pixel of
; an 8-pixel-aligned color byte -- there's no room to its left within that
; byte for an isolated lead pixel without colliding with the body that
; starts right there. So the lead goes 1px further left, at column 127 (the
; last pixel of the PRECEDING byte, otherwise untouched -- that's clear
; space in the gap between the words), and the body keeps its full original
; width unchanged at 128-197. See DrawP1Underline for why the split has to
; land on a byte boundary at all.
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, TEXT_COLOR, TEXT_ROW_I, TEXT_COL_I,
;   plus everything PixelSet/PixelClear clobber
; -----------------------------------------------------------------------------
DrawP2Underline:
  lda #1
  sta TEXT_ROW_I
  lda #71
  sta TEXT_COL_I
  lda #74
  ldx #127
  jsr EraseRect

  lda #74
  ldx #127
  ldy #TMS_WHITE
  jsr PixelSet

  ldy P2_TRAIL_COLOR
  sty TEXT_COLOR
  lda #1
  sta TEXT_COL_I
@bodyLoop:
  lda TEXT_COL_I
  clc
  adc #127
  tax
  lda #74
  ldy TEXT_COLOR
  jsr PixelSet
  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp #71
  bne @bodyLoop
  rts

; -----------------------------------------------------------------------------
; DrawGameOverScreen - per Jay: the win screen IS the gameplay screen, with
; the result text drawn directly on top of the frozen final trail
; positions. No mode switch, no full clear -- draws straight into whatever
; is already on the bitmap plane. A (or space) returns to the title
; screen, where DrawTitleScreen's own full wipe takes over.
; Erases a margin around its own text first, though (unlike the rest of
; the frozen field, which is deliberately left alone) -- the result text
; can land anywhere the round happened to end, right up against a trail,
; so it has no way to guarantee landing clear of some trail pixel's
; already-claimed 8-pixel-wide color byte the way the title screen's
; fixed-position UI can. Without erasing first, any text pixel unlucky
; enough to share a color byte with a nearby trail pixel would silently
; render in the trail's color instead of white. The erase box is padded
; well past the glyphs themselves (not just their tight bounding box) so
; the text reads as sitting in its own clear space instead of packed
; right up against whatever trail happened to end nearby.
; Vertically centered on the 192px-tall field (row 93, so the 7px-tall
; glyphs sit on rows 93-99, centered on row 96) rather than a fixed row
; that happened to work for one particular round's trail shapes.
; Hides both head sprites first -- the frozen bitmap trail is deliberate,
; but the crash never reaches UpdateHeadSprites's "both alive" branch
; (see ResolveRound), so without this a dead player's sprite is left
; showing at its last pre-crash position instead of hidden, floating
; uselessly next to the actual crash site drawn into the bitmap.
; -----------------------------------------------------------------------------
DrawGameOverScreen:
  jsr InitHeadSprites

  lda ROUND_RESULT
  cmp #1
  bne @checkP2
  lda #<WinnerP1
  ldy #>WinnerP1
  jmp @haveWinner
@checkP2:
  lda ROUND_RESULT
  cmp #2
  bne @drawMsg
  lda #<WinnerP2
  ldy #>WinnerP2
  jmp @haveWinner
@drawMsg:
  lda #<WinnerDraw
  ldy #>WinnerDraw
@haveWinner:
  sta TEXT_STR_PTR
  sty TEXT_STR_PTR+1

  lda #19                   ; 7px glyph height + 6px margin top/bottom
  sta TEXT_ROW_I
  lda #98                   ; 78px longest string ("PLAYER 1/2 WINS", 13
  sta TEXT_COL_I              ; chars x 6px) + 10px margin each side
  lda #87
  ldx #79
  jsr EraseRect

  lda #93
  sta TEXT_ROW
  lda #89
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR
  jsr DrawText
  rts

; -----------------------------------------------------------------------------
; DrawModeLine - redraws only the "1P"/"2P" suffix after the static "MODE:"
; label DrawTitleScreen already drew once. Erases just those 2 characters
; (12x7 pixels) before redrawing, not the whole line -- PixelSet only ever
; turns pixels on, so redrawing "2P" over "1P" without erasing first would
; just overlay the new glyph's pixels on the old one instead of replacing
; it, leaving a garbled blob that never looks like it updated.
;
; The value starts at column 136, not immediately after the label at 134 --
; the TMS9918 color table is one byte per 8 horizontal pixels, and "MODE:"'s
; colon lives in the pixel-128-135 byte. EraseRect's PixelClear resets a
; pixel's whole 8-wide color byte back to "unclaimed" unconditionally, so
; erasing anything in columns 134-135 would silently blow away the colon's
; already-claimed white color the moment this first runs, leaving it
; rendering black-on-black despite its bitmap bits being untouched. Starting
; the erase/redraw at column 136 keeps it in the next color byte entirely.
; -----------------------------------------------------------------------------
DrawModeLine:
  lda GAME_MODE
  cmp LAST_GAME_MODE
  beq @unchanged
  sta LAST_GAME_MODE

  lda #7
  sta TEXT_ROW_I
  lda #12
  sta TEXT_COL_I
  lda #88
  ldx #136
  jsr EraseRect

  lda #88
  sta TEXT_ROW
  lda #136
  sta TEXT_COL
  lda #TMS_WHITE
  sta TEXT_COLOR

  lda GAME_MODE
  cmp #MODE_1P
  bne @mode2
  lda #<ModeSuffix1P
  sta TEXT_STR_PTR
  lda #>ModeSuffix1P
  sta TEXT_STR_PTR+1
  jmp DrawText
@mode2:
  lda #<ModeSuffix2P
  sta TEXT_STR_PTR
  lda #>ModeSuffix2P
  sta TEXT_STR_PTR+1
  jmp DrawText
@unchanged:
  rts

; -----------------------------------------------------------------------------
; DrawColorLines - redraws only the two color swatches (the "P1/P2 COLOR:"
; labels are static, drawn once by DrawTitleScreen), and the matching title
; underline (DrawP1Underline/DrawP2Underline), so the underline color tracks
; the picker live instead of only reflecting whatever it was when the title
; screen was first entered. See DrawModeLine for why the swatch needs
; erasing before it's redrawn in a new color.
; -----------------------------------------------------------------------------
DrawColorLines:
  lda P1_COLOR_IDX
  cmp LAST_P1_COLOR_IDX
  beq @p1Unchanged
  sta LAST_P1_COLOR_IDX

  lda #7                    ; erase the old swatch first -- see
  sta TEXT_ROW_I              ; DrawModeLine for why
  lda #7
  sta TEXT_COL_I
  lda #105
  ldx #136
  jsr EraseRect

  ldx P1_COLOR_IDX
  lda TrailFgColorTable,x
  tay
  lda #105
  ldx #136
  jsr DrawColorSwatch
  jsr DrawP1Underline
@p1Unchanged:

  lda P2_COLOR_IDX
  cmp LAST_P2_COLOR_IDX
  beq @p2Unchanged
  sta LAST_P2_COLOR_IDX

  lda #7                    ; erase the old swatch first -- see
  sta TEXT_ROW_I              ; DrawModeLine for why
  lda #7
  sta TEXT_COL_I
  lda #116
  ldx #136
  jsr EraseRect

  ldx P2_COLOR_IDX
  lda TrailFgColorTable,x
  tay
  lda #116
  ldx #136
  jsr DrawColorSwatch
  jsr DrawP2Underline
@p2Unchanged:
  rts

; -----------------------------------------------------------------------------
; HandleColorPicker - lets each player cycle their own trail color with
; LEFT/RIGHT on their own joystick, or A/D (P1) / arrow LEFT-RIGHT (P2) on
; the keyboard as a fallback. Reuses JOY_STATE/JOY_STATE2 and KB_DIR_P1/
; KB_DIR_P2 already populated this tick by PollInput/PollInputP2 (see
; LightCycles.asm's MainLoop) instead of re-reading hardware or re-draining
; the keyboard - Chrin's buffer is already empty by the time this runs.
; Joystick-first per player: if that player's joystick shows LEFT or RIGHT
; this poll, the keyboard is not consulted this poll. MENU_P1_PREV/
; MENU_P2_PREV debounce on release exactly as before, now covering both
; input sources - holding either (or switching between them without a
; release in between) will not repeatedly re-trigger a color change.
; -----------------------------------------------------------------------------
HandleColorPicker:
  ; P1: synthesize an effective LEFT/RIGHT byte - joystick 1 as read this
  ; tick by PollInput's PollJoy1 call, or (only if idle on both bits) this
  ; tick's WASD result (KB_DIR_P1) from PollInput's DrainKeyboardSplit call.
  lda JOY_STATE
  and #(JOY_LEFT | JOY_RIGHT)
  sta PICKER_TMP
  cmp #(JOY_LEFT | JOY_RIGHT)
  bne @p1Have
  lda #(JOY_LEFT | JOY_RIGHT)
  ldx KB_DIR_P1
  cpx #DIR_LEFT
  bne @p1NotKbLeft
  and #JOY_RIGHT
@p1NotKbLeft:
  cpx #DIR_RIGHT
  bne @p1NotKbRight
  and #JOY_LEFT
@p1NotKbRight:
  sta PICKER_TMP
@p1Have:
  lda PICKER_TMP
  and #JOY_LEFT
  bne @p1NoLeft
  lda MENU_P1_PREV
  bne @p1NoLeft
  jsr DecP1Color
@p1NoLeft:
  lda PICKER_TMP
  and #JOY_RIGHT
  bne @p1NoRight
  lda MENU_P1_PREV
  bne @p1NoRight
  jsr IncP1Color
@p1NoRight:
  lda PICKER_TMP
  and #(JOY_LEFT | JOY_RIGHT)
  cmp #(JOY_LEFT | JOY_RIGHT)
  beq @p1Release
  lda #1
  sta MENU_P1_PREV
  jmp @p2
@p1Release:
  stz MENU_P1_PREV

@p2:
  ; P2: same synthesis, using JOY_STATE2 (PollInputP2's PollJoy2 this
  ; tick) and KB_DIR_P2 (arrow keys, same DrainKeyboardSplit call).
  lda JOY_STATE2
  and #(JOY_LEFT | JOY_RIGHT)
  sta PICKER_TMP
  cmp #(JOY_LEFT | JOY_RIGHT)
  bne @p2Have
  lda #(JOY_LEFT | JOY_RIGHT)
  ldx KB_DIR_P2
  cpx #DIR_LEFT
  bne @p2NotKbLeft
  and #JOY_RIGHT
@p2NotKbLeft:
  cpx #DIR_RIGHT
  bne @p2NotKbRight
  and #JOY_LEFT
@p2NotKbRight:
  sta PICKER_TMP
@p2Have:
  lda PICKER_TMP
  and #JOY_LEFT
  bne @p2NoLeft
  lda MENU_P2_PREV
  bne @p2NoLeft
  jsr DecP2Color
@p2NoLeft:
  lda PICKER_TMP
  and #JOY_RIGHT
  bne @p2NoRight
  lda MENU_P2_PREV
  bne @p2NoRight
  jsr IncP2Color
@p2NoRight:
  lda PICKER_TMP
  and #(JOY_LEFT | JOY_RIGHT)
  cmp #(JOY_LEFT | JOY_RIGHT)
  beq @p2Release
  lda #1
  sta MENU_P2_PREV
  rts
@p2Release:
  stz MENU_P2_PREV
  rts

; -----------------------------------------------------------------------------
; IncP1Color/DecP1Color/IncP2Color/DecP2Color - cycle a player's trail
; color index, skipping past whatever the OTHER player currently has
; selected. Same-colored trails are only distinguishable by the head
; sprites (both flat white, independent of trail color), not by the
; trail itself, so letting both players land on the same color is a real
; way to confuse yourself for no benefit -- worth blocking outright rather
; than leaving it as a footgun, since 6 of 7 colors are still available
; either way. Only ever skips one extra step: landing on a clash after a
; single +1/-1 move can only happen once before moving away from it.
; -----------------------------------------------------------------------------
IncP1Color:
  lda P1_COLOR_IDX
  cmp #6
  bne @p1Inc
  stz P1_COLOR_IDX
  bra @p1Clash
@p1Inc:
  inc P1_COLOR_IDX
@p1Clash:
  lda P1_COLOR_IDX
  cmp P2_COLOR_IDX
  bne @p1Done
  lda P1_COLOR_IDX
  cmp #6
  bne @p1Inc2
  stz P1_COLOR_IDX
  jmp ApplySelectedTrailColors
@p1Inc2:
  inc P1_COLOR_IDX
@p1Done:
  jmp ApplySelectedTrailColors

DecP1Color:
  lda P1_COLOR_IDX
  bne @p1Dec
  lda #6
  sta P1_COLOR_IDX
  bra @p1Clash
@p1Dec:
  dec P1_COLOR_IDX
@p1Clash:
  lda P1_COLOR_IDX
  cmp P2_COLOR_IDX
  bne @p1Done
  lda P1_COLOR_IDX
  bne @p1Dec2
  lda #6
  sta P1_COLOR_IDX
  jmp ApplySelectedTrailColors
@p1Dec2:
  dec P1_COLOR_IDX
@p1Done:
  jmp ApplySelectedTrailColors

IncP2Color:
  lda P2_COLOR_IDX
  cmp #6
  bne @p2Inc
  stz P2_COLOR_IDX
  bra @p2Clash
@p2Inc:
  inc P2_COLOR_IDX
@p2Clash:
  lda P2_COLOR_IDX
  cmp P1_COLOR_IDX
  bne @p2Done
  lda P2_COLOR_IDX
  cmp #6
  bne @p2Inc2
  stz P2_COLOR_IDX
  jmp ApplySelectedTrailColors
@p2Inc2:
  inc P2_COLOR_IDX
@p2Done:
  jmp ApplySelectedTrailColors

DecP2Color:
  lda P2_COLOR_IDX
  bne @p2Dec
  lda #6
  sta P2_COLOR_IDX
  bra @p2Clash
@p2Dec:
  dec P2_COLOR_IDX
@p2Clash:
  lda P2_COLOR_IDX
  cmp P1_COLOR_IDX
  bne @p2Done
  lda P2_COLOR_IDX
  bne @p2Dec2
  lda #6
  sta P2_COLOR_IDX
  jmp ApplySelectedTrailColors
@p2Dec2:
  dec P2_COLOR_IDX
@p2Done:
  jmp ApplySelectedTrailColors

ApplySelectedTrailColors:
  ldx P1_COLOR_IDX
  lda TrailFgColorTable,x
  sta P1_TRAIL_COLOR

  ldx P2_COLOR_IDX
  lda TrailFgColorTable,x
  sta P2_TRAIL_COLOR
  rts

; -----------------------------------------------------------------------------
; SetModeFromInput - up or down (either player) toggles GAME_MODE between
; 1P/2P, rather than a fixed up=1P/down=2P mapping. NEXT_DIR can't drive
; this: it's deliberately sticky for gameplay (a bike keeps its last
; heading even with no input), so it never goes back to "nothing pressed"
; and would toggle on every single tick a direction was last left facing
; up/down. Synthesizes an effective UP/DOWN byte per player exactly like
; HandleColorPicker's left/right synthesis (joystick first, WASD/arrow
; fallback only when that player's stick is idle), ANDs P1's and P2's
; bytes together so a press on either side counts, and MENU_MODE_PREV
; debounces it to one toggle per press-release cycle.
; -----------------------------------------------------------------------------
SetModeFromInput:
  lda JOY_STATE
  and #(JOY_UP | JOY_DOWN)
  sta PICKER_TMP
  cmp #(JOY_UP | JOY_DOWN)
  bne @p1Have
  lda #(JOY_UP | JOY_DOWN)
  ldx KB_DIR_P1
  cpx #DIR_UP
  bne @p1NotKbUp
  and #JOY_DOWN
@p1NotKbUp:
  cpx #DIR_DOWN
  bne @p1NotKbDown
  and #JOY_UP
@p1NotKbDown:
  sta PICKER_TMP
@p1Have:

  lda JOY_STATE2
  and #(JOY_UP | JOY_DOWN)
  sta SCAN_TMP2
  cmp #(JOY_UP | JOY_DOWN)
  bne @p2Have
  lda #(JOY_UP | JOY_DOWN)
  ldx KB_DIR_P2
  cpx #DIR_UP
  bne @p2NotKbUp
  and #JOY_DOWN
@p2NotKbUp:
  cpx #DIR_DOWN
  bne @p2NotKbDown
  and #JOY_UP
@p2NotKbDown:
  sta SCAN_TMP2
@p2Have:

  lda PICKER_TMP
  and SCAN_TMP2
  cmp #(JOY_UP | JOY_DOWN)
  bne @pressed
  stz MENU_MODE_PREV
  rts
@pressed:
  lda MENU_MODE_PREV
  bne @done
  lda #1
  sta MENU_MODE_PREV
  lda GAME_MODE
  eor #1
  sta GAME_MODE
@done:
  rts

TitleLine1:
  .byte "LIGHT CYCLES",0

TitleLine4:
  .byte "A: START",0

WinnerP1:
  .byte "PLAYER 1 WINS",0

WinnerP2:
  .byte "PLAYER 2 WINS",0

WinnerDraw:
  .byte "DOUBLE CRASH",0

ModeLabel:
  .byte "MODE:",0

ModeSuffix1P:
  .byte " 1P",0

ModeSuffix2P:
  .byte " 2P",0

P1ColorLabel:
  .byte "P1:",0

P2ColorLabel:
  .byte "P2:",0

; One saturated, vivid shade per hue -- rendered every candidate shade to
; the screen and looked at them side by side rather than going by name.
; Result: for red and yellow specifically, the "light" tier is the pastel
; one (salmon, pale khaki) and the "medium"/"dark" tier is the more vivid,
; saturated look (true red, golden yellow) -- backwards from what the
; names suggest. Blue's the exception: LT_BLUE reads as a rich periwinkle,
; not pastel, so it stays over DK_BLUE. Green only offers MED_GREEN as the
; vivid pick over the minty LT_GREEN. CYAN and MAGENTA only come in one
; (already vivid) shade. GRAY rounds it out as a neutral -- WHITE was
; considered too, but it's close enough to GRAY to not read as a distinct
; option, and would've meant the lead pixel/head sprite (both hardcoded
; white) blending into that one trail color instead of standing out.
TrailFgColorTable:
  .byte TMS_MED_RED, TMS_DK_YELLOW, TMS_MED_GREEN, TMS_CYAN, TMS_LT_BLUE, TMS_MAGENTA, TMS_GRAY

ApplyRequestedTurns:
  ; P1: reject exact 180 reversals.
  lda P1_DIR
  cmp #DIR_UP
  bne @p1NotUp
  lda P1_NEXT_DIR
  cmp #DIR_DOWN
  beq @p1Done
@p1NotUp:
  lda P1_DIR
  cmp #DIR_DOWN
  bne @p1NotDown
  lda P1_NEXT_DIR
  cmp #DIR_UP
  beq @p1Done
@p1NotDown:
  lda P1_DIR
  cmp #DIR_LEFT
  bne @p1NotLeft
  lda P1_NEXT_DIR
  cmp #DIR_RIGHT
  beq @p1Done
@p1NotLeft:
  lda P1_DIR
  cmp #DIR_RIGHT
  bne @p1Apply
  lda P1_NEXT_DIR
  cmp #DIR_LEFT
  beq @p1Done
@p1Apply:
  ; Turning onto a vertical heading (UP/DOWN) is only gated by X being
  ; byte-aligned (a multiple of 8, matching the TMS9918 color table's own
  ; 8-pixel granularity) when P2 actually has a claim somewhere in the
  ; column of color bytes this turn is about to travel through -- see
  ; the big comment on PixelSetP1Trail for why two different-colored
  ; trails sharing part of one 8-pixel-wide color byte can never both
  ; render correctly, full stop, on this hardware. That's only a real
  ; risk when the other trail is somewhere nearby; the overwhelming
  ; majority of turns happen nowhere near P2's trail at all, and gating
  ; every single one of those unconditionally meant instant turns almost
  ; never happened -- up to 7 ticks (560ms at this game's 80ms tick) of
  ; input lag on turns that were never actually in any danger of a color
  ; clash. PathClearOfOpponent scans P2_OWN_BUF down the whole column
  ; this run is about to travel, from my current row out to the wall --
  ; not just my current row, which used to miss a P2 trail sitting
  ; further down the same column and let the turn through anyway, only
  ; to bleed once the run reached it. Empty the whole way means turning
  ; right now is completely safe, so it takes effect immediately, same
  ; as it always did before any of this. Only when P2 already claims
  ; some row along that column does the alignment gate kick in, exactly
  ; as before. (The one case this still can't see is a P2 trail that
  ; hasn't reached that column yet AT ALL -- there's nothing in memory
  ; yet to scan for a move P2 hasn't made. That residual case falls back
  ; to the majority-vote/white-clash system in PixelSetP1Trail, same as
  ; any other near-miss.)
  lda P1_NEXT_DIR
  cmp #DIR_UP
  beq @p1CheckSafety
  cmp #DIR_DOWN
  beq @p1CheckSafety
  sta P1_DIR
  jmp @p1Done
@p1CheckSafety:
  lda P1_X
  sta SCAN_TMP2
  lda P1_Y
  sta SCAN_TMP
  lda #<P2_OWN_BUF
  sta FONT_PTR
  lda #>P2_OWN_BUF
  sta FONT_PTR+1
  lda P1_NEXT_DIR
  jsr PathClearOfOpponent
  bcc @p1CheckAlign
  lda P1_NEXT_DIR
  sta P1_DIR
  jmp @p1Done
@p1CheckAlign:
  lda P1_X
  and #7
  bne @p1Done
  lda P1_NEXT_DIR
  sta P1_DIR
@p1Done:

  ; P2: same reversal rule.
  lda P2_DIR
  cmp #DIR_UP
  bne @p2NotUp
  lda P2_NEXT_DIR
  cmp #DIR_DOWN
  beq @p2Done
@p2NotUp:
  lda P2_DIR
  cmp #DIR_DOWN
  bne @p2NotDown
  lda P2_NEXT_DIR
  cmp #DIR_UP
  beq @p2Done
@p2NotDown:
  lda P2_DIR
  cmp #DIR_LEFT
  bne @p2NotLeft
  lda P2_NEXT_DIR
  cmp #DIR_RIGHT
  beq @p2Done
@p2NotLeft:
  lda P2_DIR
  cmp #DIR_RIGHT
  bne @p2Apply
  lda P2_NEXT_DIR
  cmp #DIR_LEFT
  beq @p2Done
@p2Apply:
  ; Same opponent-proximity scan as P1 -- see the comment there. Checks
  ; P1_OWN_BUF instead, since P1 is the "other trail" from P2's side.
  lda P2_NEXT_DIR
  cmp #DIR_UP
  beq @p2CheckSafety
  cmp #DIR_DOWN
  beq @p2CheckSafety
  sta P2_DIR
  jmp @p2Done
@p2CheckSafety:
  lda P2_X
  sta SCAN_TMP2
  lda P2_Y
  sta SCAN_TMP
  lda #<P1_OWN_BUF
  sta FONT_PTR
  lda #>P1_OWN_BUF
  sta FONT_PTR+1
  lda P2_NEXT_DIR
  jsr PathClearOfOpponent
  bcc @p2CheckAlign
  lda P2_NEXT_DIR
  sta P2_DIR
  jmp @p2Done
@p2CheckAlign:
  lda P2_X
  and #7
  bne @p2Done
  lda P2_NEXT_DIR
  sta P2_DIR
@p2Done:
  rts

; -----------------------------------------------------------------------------
; PathClearOfOpponent -- scans a vertical strip (fixed column, from the
; mover's current row out to the arena wall in the direction it's about
; to turn) for any row where the opponent already owns part of that
; row's shared color byte. See the comment in ApplyRequestedTurns for
; why this exists: the old check only looked at the mover's current row,
; blind to the same opponent trail sitting one row further down the
; column the turn is about to travel through for potentially many rows.
;
; In:  SCAN_TMP2 = column (X), SCAN_TMP = starting row (Y, mover's
;      current row), A = DIR_UP or DIR_DOWN (the heading being turned
;      onto)
;      FONT_PTR/FONT_PTR+1 = opponent's *_OWN_BUF base address, reused
;      here as a plain input pointer -- DrawChar, its only other user,
;      never runs during a gameplay tick (see TickPlaying), so there's
;      nothing to clobber
; Out: carry set = whole strip clear (turn is safe right now); carry
;      clear = opponent already owns part of some row in the strip
;      (caller falls back to the existing alignment gate)
; Clobbers: A, X, Y, SCAN_TMP, WORK_PTR, OFFSET_LO/HI, NUM_TMP,
;           AI_TEST_X/AI_TEST_Y (all via ComputePixelAddress)
; -----------------------------------------------------------------------------
PathClearOfOpponent:
  cmp #DIR_UP
  beq @upLoop
@downLoop:
  lda SCAN_TMP
  ldx SCAN_TMP2
  jsr ComputePixelAddress
  lda OFFSET_LO
  clc
  adc FONT_PTR
  sta WORK_PTR
  lda OFFSET_HI
  adc FONT_PTR+1
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  bne @hit
  lda SCAN_TMP
  cmp #191
  beq @clear
  inc SCAN_TMP
  bra @downLoop
@upLoop:
  lda SCAN_TMP
  ldx SCAN_TMP2
  jsr ComputePixelAddress
  lda OFFSET_LO
  clc
  adc FONT_PTR
  sta WORK_PTR
  lda OFFSET_HI
  adc FONT_PTR+1
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  bne @hit
  lda SCAN_TMP
  beq @clear
  dec SCAN_TMP
  bra @upLoop
@clear:
  sec
  rts
@hit:
  clc
  rts

; -----------------------------------------------------------------------------
; ComputeP2LeftTurn / ComputeP2RightTurn -- the 90-degree turn-candidate
; tables, factored out so ComputeP2AIDirection can try them in either
; order (see the coin flip there). In: P2_DIR. Out: A = the candidate
; direction for that turn from the current heading.
;
; Each case returns immediately after its lda instead of falling through
; to a shared exit via bne. The old inline right-turn table used that
; fall-through idiom and it broke for DIR_UP, which is 0: "lda #DIR_UP /
; bne @rightReady" never branches when A is 0, so the LEFT-heading case
; silently fell through into DIR_DOWN instead of DIR_UP -- P2 never even
; tried its "up" escape when heading left. Returning per-case avoids that
; class of bug rather than reproducing it here.
; -----------------------------------------------------------------------------
ComputeP2LeftTurn:
  lda P2_DIR
  cmp #DIR_UP
  bne @lNotUp
  lda #DIR_LEFT
  rts
@lNotUp:
  lda P2_DIR
  cmp #DIR_DOWN
  bne @lNotDown
  lda #DIR_RIGHT
  rts
@lNotDown:
  lda P2_DIR
  cmp #DIR_LEFT
  bne @lNotLeft
  lda #DIR_DOWN
  rts
@lNotLeft:
  lda #DIR_UP
  rts

ComputeP2RightTurn:
  lda P2_DIR
  cmp #DIR_UP
  bne @rNotUp
  lda #DIR_RIGHT
  rts
@rNotUp:
  lda P2_DIR
  cmp #DIR_DOWN
  bne @rNotDown
  lda #DIR_LEFT
  rts
@rNotDown:
  lda P2_DIR
  cmp #DIR_LEFT
  bne @rNotLeft
  lda #DIR_UP
  rts
@rNotLeft:
  lda #DIR_DOWN
  rts

; -----------------------------------------------------------------------------
; DirTowardP1 -- which of the two directions perpendicular to P2's
; CURRENT heading closes the distance to P1 on the axis that matters.
; P2_DIR horizontal -> compares Y (result is DIR_UP/DIR_DOWN). P2_DIR
; vertical -> compares X (result is DIR_LEFT/DIR_RIGHT). Out: A = that
; direction, or $FF if P1 is exactly level with P2 on that axis (no
; preference either way).
; -----------------------------------------------------------------------------
DirTowardP1:
  lda P2_DIR
  cmp #DIR_LEFT
  beq @axisIsY
  cmp #DIR_RIGHT
  beq @axisIsY

  ; P2 currently vertical -- compare X.
  lda P1_X
  cmp P2_X
  beq @tied
  bcc @wantLeft
  lda #DIR_RIGHT
  rts
@wantLeft:
  lda #DIR_LEFT
  rts

@axisIsY:
  ; P2 currently horizontal -- compare Y.
  lda P1_Y
  cmp P2_Y
  beq @tied
  bcc @wantUp
  lda #DIR_DOWN
  rts
@wantUp:
  lda #DIR_UP
  rts

@tied:
  lda #$FF
  rts

; -----------------------------------------------------------------------------
; ComputeP2AIDirection -- picks P2_NEXT_DIR from three candidates:
; continue straight, turn left, turn right.
;
; Continuing straight is preferred whenever it's safe -- but not
; absolutely: about 1 time in 16, even a safe straight run gets
; second-guessed and a turn is looked for anyway. Without this, P2 was a
; pure wall-follower that never changed course unless a wall forced it
; to, which is exactly what made it feel predictable and never actually
; came at P1 -- it only ever reacted to geometry, never to the other
; player.
;
; When a turn IS being considered (forced or not), left and right used
; to be a flat coin flip. Now DirTowardP1 picks whichever turn actually
; closes the distance to P1 on the relevant axis, and that's preferred
; about 3 times out of 4 -- not always, since an AI that beelines for
; the player with zero variance is its own kind of predictable, and the
; remaining 1-in-4 (or ties, where neither side is objectively better)
; falls back to the old plain coin flip.
; -----------------------------------------------------------------------------
ComputeP2AIDirection:
  lda P2_DIR
  sta AI_DIR_TMP
  jsr IsDirectionSafeP2
  bcc @pickTurn

  ; Continuing straight is safe -- usually just take it, but roll a
  ; small chance to look for a turn anyway.
  jsr AdvanceRng
  and #$0F
  bne @keepCurrent

@pickTurn:
  jsr DirTowardP1
  sta AI_PREFERRED_DIR
  cmp #$FF
  beq @coinFlip
  jsr AdvanceRng
  and #3
  cmp #3
  beq @coinFlip
  jsr ComputeP2LeftTurn
  cmp AI_PREFERRED_DIR
  beq @tryLeftFirst
  jmp @tryRightFirst

@coinFlip:
  jsr AdvanceRng
  lsr a
  bcs @tryRightFirst

@tryLeftFirst:
  jsr ComputeP2LeftTurn
  sta AI_DIR_TMP
  jsr IsDirectionSafeP2
  bcs @useAiDir
  jsr ComputeP2RightTurn
  sta AI_DIR_TMP
  jsr IsDirectionSafeP2
  bcs @useAiDir
  jmp @noSafeTurn

@tryRightFirst:
  jsr ComputeP2RightTurn
  sta AI_DIR_TMP
  jsr IsDirectionSafeP2
  bcs @useAiDir
  jsr ComputeP2LeftTurn
  sta AI_DIR_TMP
  jsr IsDirectionSafeP2
  bcs @useAiDir

@noSafeTurn:
  ; No safe turn found: keep current.
  lda P2_DIR
  sta P2_NEXT_DIR
  rts

@keepCurrent:
  lda P2_DIR
  sta P2_NEXT_DIR
  rts

@useAiDir:
  lda AI_DIR_TMP
  sta P2_NEXT_DIR
  rts

; -----------------------------------------------------------------------------
; IsDirectionSafeP2 - In: AI_DIR_TMP = candidate direction, using current
; P2_X/P2_Y. Out: carry set if safe, clear if not.
; A candidate turn from a horizontal heading onto UP/DOWN doesn't
; necessarily take effect next tick the way a plain 1-step lookahead
; assumes -- ApplyRequestedTurns holds a turn onto a vertical heading
; until P2_X is grid-aligned (see the comment there), so P2 is committed
; to continuing in its CURRENT direction for however many pixels remain
; until that happens, not just the one step this used to check. Confirmed
; via the debugger: the AI picked UP as "safe" one pixel from the border
; while off-grid, the turn was held, and P2 drove straight into the wall
; it had supposedly already decided to avoid. When the candidate is
; vertical and the current heading is horizontal, walk every pixel of
; that committed path first, then check the vertical step from wherever
; it actually lands -- that's the real distance to safety, not 1 pixel.
;
; Continuing straight while ALREADY horizontal gets the same treatment,
; for a different reason: ComputeP2AIDirection only looks for an escape
; once continuing straight is unsafe, and a plain 1-step check doesn't
; call that unsafe until the wall is the very next pixel -- by which
; point P2 has typically already sailed past whatever grid line would
; have let a turn through in time, and lands back off-grid with no room
; left for the delay above. Confirmed the same way: P2 ran straight
; through a fully aligned column with room to spare, reacted for the
; first time one pixel from the border, and had nowhere left to turn.
; Looking 8 pixels ahead here -- worst-case turn delay -- means the AI
; calls "continue" unsafe early enough that a gated turn still has a
; grid line to reach before whatever it saw coming actually arrives.
;
; Turning between two directions on an axis switch that ISN'T gated
; (vertical-current -> horizontal-candidate, which always takes effect
; immediately) keeps the plain single-step check -- there's no delay to
; plan around there.
;
; Continuing straight while ALREADY vertical gets the same 8-pixel scan
; as the horizontal case, for the same reason: a plain 1-step check
; doesn't call the run unsafe until the wall is the very next pixel,
; which reads as a last-instant twitch compared to the horizontal case's
; visibly-early turn -- same underlying AI, inconsistent reaction
; distance depending purely on which axis it happened to be moving on.
; This isn't a gating-delay issue the way the horizontal case was (a
; turn OFF of vertical onto horizontal is never gated, so the 1-step
; check for the two turn candidates below is already exactly correct
; and untouched) -- it's purely about giving the AI the same look-ahead
; on both axes so its behavior doesn't visibly change shape depending on
; which way it's facing.
; -----------------------------------------------------------------------------
IsDirectionSafeP2:
  lda P2_DIR
  cmp #DIR_LEFT
  beq @currentHorizontal
  cmp #DIR_RIGHT
  beq @currentHorizontal

  ; Currently vertical (UP/DOWN). The two turn candidates (onto
  ; LEFT/RIGHT) fall through to @simple's plain 1-step check, same as
  ; always -- see the comment above for why that's still exactly right.
  ; Continuing straight (AI_DIR_TMP == P2_DIR) gets the extended scan.
  lda AI_DIR_TMP
  cmp P2_DIR
  bne @notContinueV
  jmp @continueLookaheadV
@notContinueV:
  jmp @simple

@currentHorizontal:
  lda AI_DIR_TMP
  cmp #DIR_UP
  beq @gated
  cmp #DIR_DOWN
  beq @gated
  bra @continueLookahead

@continueLookahead:
  ; AI_DIR_TMP must equal P2_DIR here (horizontal continue) -- turning
  ; onto the opposite horizontal direction is a reversal and never a
  ; candidate ComputeP2AIDirection generates.
  lda P2_X
  sta AI_TEST_X
  lda P2_Y
  sta AI_TEST_Y
  lda #8
  sta SCAN_TMP2
@clLoop:
  lda P2_DIR
  cmp #DIR_RIGHT
  bne @clDec
  inc AI_TEST_X
  bra @clCheck
@clDec:
  dec AI_TEST_X
@clCheck:
  lda AI_TEST_Y
  ldx AI_TEST_X
  jsr PixelIsSet
  bne @clBlocked
  dec SCAN_TMP2
  bne @clLoop
  sec
  rts
@clBlocked:
  clc
  rts

@gated:
  ; Mirror ApplyRequestedTurns's own instant-vs-gated decision instead of
  ; always assuming the slow (walk-to-alignment) case. If P1's trail
  ; doesn't occupy the column P2 is about to turn into anywhere between
  ; here and the wall, ApplyRequestedTurns applies the turn INSTANTLY at
  ; P2's current, possibly-unaligned X -- not at some future aligned X.
  ; Checking safety at the walked-forward aligned position in that case
  ; verifies a cell P2 was never actually going to move into, while the
  ; cell it really moves into (one step vertically from right here)
  ; never gets checked at all. Confirmed via the debugger: a turn this
  ; check called safe landed P2 on an occupied pixel it had never
  ; examined, because the real move applied instantly at the current
  ; column while this check had verified a different, aligned column
  ; several pixels further along.
  lda P2_X
  sta SCAN_TMP2
  lda P2_Y
  sta SCAN_TMP
  lda #<P1_OWN_BUF
  sta FONT_PTR
  lda #>P1_OWN_BUF
  sta FONT_PTR+1
  lda AI_DIR_TMP
  jsr PathClearOfOpponent
  bcc @gatedWalk
  ; Clear the whole way -- the turn applies instantly, right here.
  lda P2_X
  sta AI_TEST_X
  lda P2_Y
  sta AI_TEST_Y
  bra @gatedAligned
@gatedWalk:
  lda P2_X
  sta AI_TEST_X
  lda P2_Y
  sta AI_TEST_Y
@gatedLoop:
  lda AI_TEST_X
  and #7
  beq @gatedAligned
  lda P2_DIR
  cmp #DIR_RIGHT
  bne @gatedDec
  inc AI_TEST_X
  bra @gatedStepCheck
@gatedDec:
  dec AI_TEST_X
@gatedStepCheck:
  lda AI_TEST_Y
  ldx AI_TEST_X
  jsr PixelIsSet
  beq @gatedLoop
  clc
  rts
@gatedAligned:
  lda AI_DIR_TMP
  cmp #DIR_UP
  bne @gatedDown
  dec AI_TEST_Y
  bra @gatedFinal
@gatedDown:
  inc AI_TEST_Y
@gatedFinal:
  lda AI_TEST_Y
  cmp #192
  bcs @gatedBlocked
  lda AI_TEST_Y
  ldx AI_TEST_X
  jsr PixelIsSet
  beq @gatedSafe
@gatedBlocked:
  clc
  rts
@gatedSafe:
  sec
  rts

@continueLookaheadV:
  ; AI_DIR_TMP must equal P2_DIR here (vertical continue) -- see the
  ; header comment above. Same shape as @continueLookahead, just walking
  ; AI_TEST_Y instead of AI_TEST_X, with the same #192 bounds check
  ; @simple/@gated already use for a Y move (also catches the top edge:
  ; decrementing AI_TEST_Y past 0 wraps to 255, which is >= 192 too).
  lda P2_X
  sta AI_TEST_X
  lda P2_Y
  sta AI_TEST_Y
  lda #8
  sta SCAN_TMP2
@clvLoop:
  lda P2_DIR
  cmp #DIR_DOWN
  bne @clvDec
  inc AI_TEST_Y
  bra @clvCheck
@clvDec:
  dec AI_TEST_Y
@clvCheck:
  lda AI_TEST_Y
  cmp #192
  bcs @clvBlocked
  lda AI_TEST_Y
  ldx AI_TEST_X
  jsr PixelIsSet
  bne @clvBlocked
  dec SCAN_TMP2
  bne @clvLoop
  sec
  rts
@clvBlocked:
  clc
  rts

@simple:
  lda P2_X
  sta AI_TEST_X
  lda P2_Y
  sta AI_TEST_Y

  lda AI_DIR_TMP
  cmp #DIR_UP
  bne @sNotUp
  dec AI_TEST_Y
@sNotUp:
  lda AI_DIR_TMP
  cmp #DIR_DOWN
  bne @sNotDown
  inc AI_TEST_Y
@sNotDown:
  lda AI_DIR_TMP
  cmp #DIR_LEFT
  bne @sNotLeft
  dec AI_TEST_X
@sNotLeft:
  lda AI_DIR_TMP
  cmp #DIR_RIGHT
  bne @sCheck
  inc AI_TEST_X

@sCheck:
  lda AI_TEST_Y
  cmp #192
  bcs @blocked
  lda AI_TEST_Y
  ldx AI_TEST_X
  jsr PixelIsSet
  beq @safe
@blocked:
  clc
  rts
@safe:
  sec
  rts

ComputeNextPositions:
  lda P1_X
  sta P1_NEXT_X
  lda P1_Y
  sta P1_NEXT_Y

  lda P1_DIR
  cmp #DIR_UP
  bne @p1NotUp
  dec P1_NEXT_Y
@p1NotUp:
  lda P1_DIR
  cmp #DIR_DOWN
  bne @p1NotDown
  inc P1_NEXT_Y
@p1NotDown:
  lda P1_DIR
  cmp #DIR_LEFT
  bne @p1NotLeft
  dec P1_NEXT_X
@p1NotLeft:
  lda P1_DIR
  cmp #DIR_RIGHT
  bne @p1Done
  inc P1_NEXT_X
@p1Done:

  lda P2_X
  sta P2_NEXT_X
  lda P2_Y
  sta P2_NEXT_Y

  lda P2_DIR
  cmp #DIR_UP
  bne @p2NotUp
  dec P2_NEXT_Y
@p2NotUp:
  lda P2_DIR
  cmp #DIR_DOWN
  bne @p2NotDown
  inc P2_NEXT_Y
@p2NotDown:
  lda P2_DIR
  cmp #DIR_LEFT
  bne @p2NotLeft
  dec P2_NEXT_X
@p2NotLeft:
  lda P2_DIR
  cmp #DIR_RIGHT
  bne @p2Done
  inc P2_NEXT_X
@p2Done:
  rts

CommitP1Move:
  lda P1_NEXT_X
  sta P1_X
  lda P1_NEXT_Y
  sta P1_Y

  lda P1_Y
  ldx P1_X
  jsr PixelSetP1Trail
  rts

CommitP2Move:
  lda P2_NEXT_X
  sta P2_X
  lda P2_NEXT_Y
  sta P2_Y

  lda P2_Y
  ldx P2_X
  jsr PixelSetP2Trail
  rts
