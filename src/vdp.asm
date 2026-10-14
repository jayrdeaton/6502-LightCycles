; =============================================================================
;   vdp.asm - TMS9918 Graphics II bitmap renderer for LightCycles
; =============================================================================

.segment "CART"

NAME_TABLE_BASE  = $1800
COLOR_TABLE_BASE = $2000
SPR_ATTR_BASE    = $1B00
SPR_PAT_BASE     = $3800

DEFAULT_TRAIL_COLOR = (TMS_LT_BLUE << 4) | TMS_BLACK
BORDER_FG           = TMS_LT_BLUE
COLOR_EMPTY         = (TMS_BLACK << 4) | TMS_BLACK

VdpWriteReg:
  php
  sei
  sta VC_REG
  txa
  ora #$80
  sta VC_REG
  plp
  rts

VdpSetAddr:
  php
  sei
  sta VC_REG
  txa
  ora #$40
  sta VC_REG
  plp
  rts

InitGraphicsI:
  lda HW_PRESENT
  and #HW_VID
  bne @haveVideo
@halt:
  bra @halt

@haveVideo:
  ; Blank while reprogramming mode and tables.
  lda #$80
  ldx #1
  jsr VdpWriteReg

  lda #$02
  ldx #0
  jsr VdpWriteReg
  lda #$80
  ldx #1
  jsr VdpWriteReg
  lda #$06
  ldx #2
  jsr VdpWriteReg
  lda #$FF
  ldx #3
  jsr VdpWriteReg
  lda #$03
  ldx #4
  jsr VdpWriteReg
  lda #$36
  ldx #5
  jsr VdpWriteReg
  lda #$07
  ldx #6
  jsr VdpWriteReg
  lda #TMS_BLACK
  ldx #7
  jsr VdpWriteReg

  jsr FillNameTable
  jsr FillColorTable
  jsr ClearScreen
  jsr InitHeadSprites

  ; Unblank display.
  lda #$C0
  ldx #1
  jsr VdpWriteReg
  rts

; Every routine below writes a long run of VC_DATA bytes after a single
; VdpSetAddr call, relying on the VDP's own address auto-increment to stay
; in step with each write -- an interrupt landing mid-run (reading VDP
; status, which resets the same two-byte write-latch these writes depend
; on) desyncs everything after it. PHP/SEI/PLP wraps the whole run, not
; just VdpSetAddr's own two-byte sequence (nesting PHP/SEI/PLP composes
; safely; nesting raw SEI/CLI does not).
FillNameTable:
  php
  sei
  lda #<NAME_TABLE_BASE
  ldx #>NAME_TABLE_BASE
  jsr VdpSetAddr

  ldx #3
@block:
  ldy #0
@seq:
  tya
  sta VC_DATA
  iny
  bne @seq
  dex
  bne @block
  plp
  rts

FillColorTable:
  php
  sei
  lda #<COLOR_TABLE_BASE
  ldx #>COLOR_TABLE_BASE
  jsr VdpSetAddr

  ldx #$18
  lda #COLOR_EMPTY
@page:
  ldy #0
@byte:
  sta VC_DATA
  iny
  bne @byte
  dex
  bne @page
  plp
  rts

InitHeadSprites:
  php
  sei
  lda #<SPR_PAT_BASE
  ldx #>SPR_PAT_BASE
  jsr VdpSetAddr

  ; Sprite pattern 0: one bright pixel in top-left.
  lda #%10000000
  sta VC_DATA
  lda #0
  ldy #7
@sp0:
  sta VC_DATA
  dey
  bne @sp0

  ; Sprite pattern 1: same single pixel.
  lda #%10000000
  sta VC_DATA
  lda #0
  ldy #7
@sp1:
  sta VC_DATA
  dey
  bne @sp1

  ; Hide both sprites initially and terminate list.
  lda #<SPR_ATTR_BASE
  ldx #>SPR_ATTR_BASE
  jsr VdpSetAddr

  lda #208
  sta VC_DATA
  lda #0
  sta VC_DATA
  sta VC_DATA
  sta VC_DATA

  lda #208
  sta VC_DATA
  lda #0
  sta VC_DATA
  sta VC_DATA
  sta VC_DATA

  lda #208
  sta VC_DATA
  plp
  rts

UpdateHeadSprites:
  php
  sei
  lda #<SPR_ATTR_BASE
  ldx #>SPR_ATTR_BASE
  jsr VdpSetAddr

  ; Sprite 0 (P1)
  lda P1_ALIVE
  beq @hide0
  lda P1_Y
  cmp #192
  bcs @hide0
  ; TMS9918 sprite Y attribute is encoded as (screen_y - 1).
  sec
  sbc #1
  sta VC_DATA
  lda P1_X
  sta VC_DATA
  lda #0
  sta VC_DATA
  lda #TMS_WHITE
  sta VC_DATA
  jmp @sprite1

@hide0:
  lda #208
  sta VC_DATA
  lda #0
  sta VC_DATA
  sta VC_DATA
  sta VC_DATA

@sprite1:
  lda P2_ALIVE
  beq @hide1
  lda P2_Y
  cmp #192
  bcs @hide1
  ; TMS9918 sprite Y attribute is encoded as (screen_y - 1).
  sec
  sbc #1
  sta VC_DATA
  lda P2_X
  sta VC_DATA
  lda #1
  sta VC_DATA
  lda #TMS_WHITE
  sta VC_DATA
  jmp @end

@hide1:
  lda #208
  sta VC_DATA
  lda #0
  sta VC_DATA
  sta VC_DATA
  sta VC_DATA

@end:
  lda #208
  sta VC_DATA
  plp
  rts

ClearScreen:
  ; Clear RAM shadow bitmap.
  lda #<BITMAP_BUF
  sta WORK_PTR
  lda #>BITMAP_BUF
  sta WORK_PTR+1
  ldx #$18
  lda #0
@ramPage:
  ldy #0
@ramByte:
  sta (WORK_PTR),y
  iny
  bne @ramByte
  inc WORK_PTR+1
  dex
  bne @ramPage

  ; Clear RAM shadow color bytes.
  lda #<COLOR_BUF
  sta WORK_PTR
  lda #>COLOR_BUF
  sta WORK_PTR+1
  ldx #$18
  lda #COLOR_EMPTY
@clrColorPage:
  ldy #0
@clrColorByte:
  sta (WORK_PTR),y
  iny
  bne @clrColorByte
  inc WORK_PTR+1
  dex
  bne @clrColorPage

  ; Clear the trail ownership planes -- stale ownership bits from a
  ; previous round would corrupt this round's majority-color voting (see
  ; PixelSetP1Trail/PixelSetP2Trail) from tick one.
  lda #<P1_OWN_BUF
  sta WORK_PTR
  lda #>P1_OWN_BUF
  sta WORK_PTR+1
  ldx #$18
  lda #0
@clrP1OwnPage:
  ldy #0
@clrP1OwnByte:
  sta (WORK_PTR),y
  iny
  bne @clrP1OwnByte
  inc WORK_PTR+1
  dex
  bne @clrP1OwnPage

  lda #<P2_OWN_BUF
  sta WORK_PTR
  lda #>P2_OWN_BUF
  sta WORK_PTR+1
  ldx #$18
  lda #0
@clrP2OwnPage:
  ldy #0
@clrP2OwnByte:
  sta (WORK_PTR),y
  iny
  bne @clrP2OwnByte
  inc WORK_PTR+1
  dex
  bne @clrP2OwnPage

  ; Clear VRAM pattern bytes (bitmap data plane). PHP/SEI/PLP wraps the
  ; whole run -- see the comment above FillNameTable for why a single
  ; VdpSetAddr followed by many VC_DATA writes needs this.
  php
  sei
  lda #$00
  ldx #$00
  jsr VdpSetAddr
  ldx #$18
  lda #0
@vramPage:
  ldy #0
@vramByte:
  sta VC_DATA
  iny
  bne @vramByte
  dex
  bne @vramPage
  plp
  rts

DrawBorder:
  ldx #ARENA_MIN_X
@top:
  lda #ARENA_MIN_Y
  jsr PixelSetBorder
  inx
  cpx #ARENA_MAX_X
  bne @top
  lda #ARENA_MIN_Y
  jsr PixelSetBorder

  ldx #ARENA_MIN_X
@bottom:
  lda #ARENA_MAX_Y
  jsr PixelSetBorder
  inx
  cpx #ARENA_MAX_X
  bne @bottom
  lda #ARENA_MAX_Y
  jsr PixelSetBorder

  lda #ARENA_MIN_Y
  sta SCAN_TMP
  inc SCAN_TMP
@sides:
  ; One pixel per row on each side, matching the top/bottom walls' own
  ; single-pixel thickness (the previous version filled a full 8-pixel
  ; byte column here, making the side walls eight times thicker than the
  ; top/bottom ones).
  ldx #ARENA_MIN_X
  lda SCAN_TMP
  jsr PixelSetBorder

  ldx #ARENA_MAX_X
  lda SCAN_TMP
  jsr PixelSetBorder

  inc SCAN_TMP
  lda SCAN_TMP
  cmp #ARENA_MAX_Y
  bne @sides
  rts

; -----------------------------------------------------------------------------
; PixelSetP1Trail / PixelSetP2Trail - draw one trail pixel, then resolve
; that pixel's 8-wide VDP color byte by majority vote instead of generic
; PixelSet's first-claim-wins rule. TMS9918 Graphics II has one
; foreground color per 8 horizontal pixels per scanline -- when both
; trails pass within 8 pixels of each other on the same row, only one
; color can ever be shown for that whole byte; that's a hardware fact, no
; way around it. But first-claim-wins meant whichever trail happened to
; touch the byte FIRST kept it forever, even after the other trail went
; on to own most of the byte's actual pixels -- a single early pixel
; could permanently mis-color a byte the other player ends up
; dominating. Recomputing the color from a real per-pixel ownership
; record (P1_OWN_BUF/P2_OWN_BUF, tracked separately from the VDP color
; table) every time either trail touches the byte means it always
; reflects whichever player currently owns more of its 8 pixels, not
; just whoever arrived first.
; An exact tie (equal ownership) renders as a flat TMS_WHITE "clash"
; instead of picking one player's color -- there IS no correct choice
; between two truly-equal owners, and forcing one still reads as a bug
; (first tried "whichever trail is drawing now," which silently always
; meant P2 since CommitP1Move always runs before CommitP2Move; then row
; parity, which alternates the two colors every row and just trades one
; glitchy-looking pattern for another). White reuses the same "shared
; boundary" language the lead pixel and head sprites already use, so two
; trails running side by side long enough to genuinely tie a byte reads
; as a deliberate spark/clash effect, not a rendering error.
; In: A = row, X = col
; Out: none
; Clobbers: A, X, Y, WORK_PTR, OFFSET_LO/HI, NUM_TMP, SCAN_TMP, SCAN_TMP2
; -----------------------------------------------------------------------------
PixelSetP1Trail:
  jsr ComputePixelAddress

  ldy #0
  lda (WORK_PTR),y
  ora NUM_TMP
  sta (WORK_PTR),y

  php
  sei
  pha
  lda OFFSET_LO
  ldx OFFSET_HI
  jsr VdpSetAddr
  pla
  sta VC_DATA
  plp

  lda OFFSET_LO                ; claim this pixel in P1's ownership plane
  clc
  adc #<P1_OWN_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>P1_OWN_BUF
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  ora NUM_TMP
  sta (WORK_PTR),y
  tax
  lda PopcountTable,x
  sta SCAN_TMP                  ; P1's bit count in this byte

  lda OFFSET_LO                ; read (not claim) P2's count in this byte
  clc
  adc #<P2_OWN_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>P2_OWN_BUF
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  tax
  lda PopcountTable,x
  sta SCAN_TMP2

  lda SCAN_TMP2
  cmp SCAN_TMP
  bcc @p1Wins                   ; P2count < P1count
  beq @tie
  lda P2_TRAIL_COLOR             ; P2count > P1count
  bra @haveColor
@p1Wins:
  lda P1_TRAIL_COLOR
  bra @haveColor
@tie:
  lda #TMS_WHITE
@haveColor:
  jmp TrailColorCommit

PixelSetP2Trail:
  jsr ComputePixelAddress

  ldy #0
  lda (WORK_PTR),y
  ora NUM_TMP
  sta (WORK_PTR),y

  php
  sei
  pha
  lda OFFSET_LO
  ldx OFFSET_HI
  jsr VdpSetAddr
  pla
  sta VC_DATA
  plp

  lda OFFSET_LO                ; claim this pixel in P2's ownership plane
  clc
  adc #<P2_OWN_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>P2_OWN_BUF
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  ora NUM_TMP
  sta (WORK_PTR),y
  tax
  lda PopcountTable,x
  sta SCAN_TMP2                 ; P2's bit count in this byte

  lda OFFSET_LO                ; read (not claim) P1's count in this byte
  clc
  adc #<P1_OWN_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>P1_OWN_BUF
  sta WORK_PTR+1
  ldy #0
  lda (WORK_PTR),y
  tax
  lda PopcountTable,x
  sta SCAN_TMP

  lda SCAN_TMP
  cmp SCAN_TMP2
  bcc @p2Wins                   ; P1count < P2count
  beq @tie
  lda P1_TRAIL_COLOR             ; P1count > P2count
  bra @haveColor
@p2Wins:
  lda P2_TRAIL_COLOR
  bra @haveColor
@tie:
  lda #TMS_WHITE
@haveColor:
  ; fall through to TrailColorCommit

; Shared tail for PixelSetP1Trail/PixelSetP2Trail: A = the winning
; player's trail color (TMS_* value); OFFSET_LO/HI still hold this
; pixel's byte offset from the ComputePixelAddress call above. Writes
; that color to the byte's VDP color-table entry unconditionally (unlike
; PixelSet's color path, which only writes when the byte was empty).
TrailColorCommit:
  asl a
  asl a
  asl a
  asl a
  ora #TMS_BLACK
  sta NUM_TMP

  lda OFFSET_LO
  clc
  adc #<COLOR_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>COLOR_BUF
  sta WORK_PTR+1
  ldy #0
  lda NUM_TMP
  sta (WORK_PTR),y

  lda OFFSET_HI
  clc
  adc #>COLOR_TABLE_BASE
  tax
  lda OFFSET_LO
  php
  sei
  jsr VdpSetAddr
  lda NUM_TMP
  sta VC_DATA
  plp
  rts

; PopcountTable[n] = number of set bits in n -- used to compare how much
; of a shared 8-pixel color byte each player currently owns.
PopcountTable:
  .byte 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
  .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
  .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
  .byte 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
  .byte 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
  .byte 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
  .byte 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
  .byte 4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8

PixelSetBorder:
  ldy #BORDER_FG
  jmp PixelSet

PixelSet:
  sty DIGIT_TMP
  phx
  phy
  jsr ComputePixelAddress
  ldy #0
  lda (WORK_PTR),y
  ora NUM_TMP
  sta (WORK_PTR),y

  php
  sei
  pha
  lda OFFSET_LO
  ldx OFFSET_HI
  jsr VdpSetAddr
  pla
  sta VC_DATA
  plp

  lda DIGIT_TMP
  asl a
  asl a
  asl a
  asl a
  ora #TMS_BLACK
  sta NUM_TMP

  ; Map the same byte offset into COLOR_BUF and only set a color once.
  lda OFFSET_LO
  clc
  adc #<COLOR_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>COLOR_BUF
  sta WORK_PTR+1

  ldy #0
  lda (WORK_PTR),y
  cmp #COLOR_EMPTY
  bne @doneColor

  lda NUM_TMP
  sta (WORK_PTR),y

  lda OFFSET_HI
  clc
  adc #>COLOR_TABLE_BASE
  tax
  lda OFFSET_LO
  php
  sei
  jsr VdpSetAddr
  lda NUM_TMP
  sta VC_DATA
  plp
@doneColor:
  ply
  plx
  rts

; -----------------------------------------------------------------------------
; PixelClear - the inverse of PixelSet: unset one pixel's bit and reset its
; color-cell back to COLOR_EMPTY unconditionally (erasing always releases
; ownership, unlike PixelSet's first-writer-wins claim). Needed because
; PixelSet only ever ORs bits on -- redrawing changed text (the title
; screen's MODE: 1P/2P line, or a color swatch after the player cycles
; color) without erasing first just overlays the new glyph's pixels on the
; old one instead of replacing it, so nothing looks like it's updating.
; In: A = row, X = col
; Out: none
; Clobbers: A, X, Y, plus everything ComputePixelAddress/VdpSetAddr clobber
; -----------------------------------------------------------------------------
PixelClear:
  phx
  phy
  jsr ComputePixelAddress

  lda NUM_TMP
  eor #$FF
  sta FONT_TMP              ; inverted mask; FONT_TMP is safe scratch here,
                              ; not concurrently used by anything on this
                              ; call path
  ldy #0
  lda (WORK_PTR),y
  and FONT_TMP
  sta (WORK_PTR),y

  php
  sei
  pha
  lda OFFSET_LO
  ldx OFFSET_HI
  jsr VdpSetAddr
  pla
  sta VC_DATA
  plp

  lda OFFSET_LO
  clc
  adc #<COLOR_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>COLOR_BUF
  sta WORK_PTR+1
  lda #COLOR_EMPTY
  ldy #0
  sta (WORK_PTR),y

  lda OFFSET_HI
  clc
  adc #>COLOR_TABLE_BASE
  tax
  lda OFFSET_LO
  php
  sei
  jsr VdpSetAddr
  lda #COLOR_EMPTY
  sta VC_DATA
  plp

  ply
  plx
  rts

; -----------------------------------------------------------------------------
; EraseRect - clear every pixel in a rectangular region, via PixelClear.
; In: A = top row, X = left col, TEXT_ROW_I/TEXT_COL_I hold the height and
;     width on entry (caller sets them as byte values before calling,
;     reusing DrawChar's scratch since the two never run concurrently)
; Out: none
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, plus everything PixelClear clobbers
; -----------------------------------------------------------------------------
EraseRect:
  sta SCAN_TMP               ; origin row
  stx SCAN_TMP2               ; origin col
  lda TEXT_ROW_I
  sta FONT_HI                  ; stash height (PixelClear doesn't touch this)
  lda TEXT_COL_I
  sta TEXT_COLOR                ; stash width -- deliberately NOT FONT_TMP,
                                  ; since PixelClear (called every iteration
                                  ; below) uses FONT_TMP as its own internal
                                  ; scratch and would clobber it

  stz TEXT_ROW_I
@rowLoop:
  stz TEXT_COL_I
@colLoop:
  lda TEXT_COL_I
  clc
  adc SCAN_TMP2
  tax
  lda TEXT_ROW_I
  clc
  adc SCAN_TMP
  jsr PixelClear

  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp TEXT_COLOR
  bne @colLoop

  inc TEXT_ROW_I
  lda TEXT_ROW_I
  cmp FONT_HI
  bne @rowLoop
  rts

PixelIsSet:
  phx
  phy
  jsr ComputePixelAddress
  ldy #0
  lda (WORK_PTR),y
  and NUM_TMP
  beq @clear
  ply
  plx
  lda #1
  rts
@clear:
  ply
  plx
  lda #0
  rts

ComputePixelAddress:
  ; In: A = y (0..191), X = x (0..255)
  ; Out: WORK_PTR points to shadow-byte, OFFSET_LO/HI = VRAM byte address,
  ;      NUM_TMP = mask bit for the pixel.
  sta AI_TEST_Y
  stx AI_TEST_X

  ; Graphics II pattern-byte address:
  ; third*0x800 + charRow*0x100 + xByte*8 + yWithinChar
  ; where third = y/64, charRow = (y&63)/8.
  lda AI_TEST_Y
  and #$07
  sta OFFSET_LO               ; yWithinChar
  stz OFFSET_HI

  lda AI_TEST_X
  lsr a
  lsr a
  lsr a
  asl a
  asl a
  asl a
  clc
  adc OFFSET_LO               ; + xByte*8
  sta OFFSET_LO
  bcc :+
  inc OFFSET_HI
:

  lda AI_TEST_Y
  and #$38                    ; char-row source bits
  lsr a
  lsr a
  lsr a                        ; charRow (0..7)
  clc
  adc OFFSET_HI               ; + charRow*256 into high byte
  sta OFFSET_HI

  lda AI_TEST_Y
  and #$C0                    ; third of screen
  lsr a
  lsr a
  lsr a
  clc
  adc OFFSET_HI               ; + third*0x800 into high byte
  sta OFFSET_HI

  lda OFFSET_LO
  clc
  adc #<BITMAP_BUF
  sta WORK_PTR
  lda OFFSET_HI
  adc #>BITMAP_BUF
  sta WORK_PTR+1

  lda AI_TEST_X
  and #$07
  tay
  lda PixelMaskTable,y
  sta NUM_TMP
  rts

PixelMaskTable:
  .byte $80, $40, $20, $10, $08, $04, $02, $01

; -----------------------------------------------------------------------------
; DrawChar - plot one character's 5x7 pixel glyph into the bitmap plane.
; In:  A = ASCII character code (space through 'Z'; anything outside that
;      range draws nothing, since no game text uses it)
;      TEXT_ROW/TEXT_COL = top-left pixel origin, TEXT_COLOR = TMS_* color
; Out: none. TEXT_ROW/TEXT_COL are left unchanged (DrawText advances
;      TEXT_COL between characters; a lone DrawChar caller can too).
; Clobbers: A, X, Y, FONT_PTR, FONT_TMP, FONT_HI, TEXT_ROW_I, TEXT_COL_I
; -----------------------------------------------------------------------------
DrawChar:
  cmp #' '
  bcc @done
  cmp #('Z'+1)
  bcs @done

  sec
  sbc #' '                 ; A = (char - ' '), index into FontData
  sta FONT_TMP
  asl a
  asl a
  clc
  adc FONT_TMP              ; A = (index*5) mod 256; carry = the bit this
                             ; 8-bit add lost -- index*5 reaches 290 for
                             ; 'Z', past what one byte holds, and that
                             ; overflow bit has to reach FONT_PTR's high
                             ; byte, not just get thrown away by a clc
  stz FONT_HI
  bcc @noHi
  inc FONT_HI
@noHi:

  clc
  adc #<FontData
  sta FONT_PTR
  lda FONT_HI
  adc #>FontData
  sta FONT_PTR+1

  stz TEXT_COL_I
@colLoop:
  ldy TEXT_COL_I
  lda (FONT_PTR),y
  sta FONT_TMP

  stz TEXT_ROW_I
@rowLoop:
  ldx TEXT_ROW_I
  lda FONT_TMP
  and FontBitMask,x
  beq @rowSkip

  lda TEXT_ROW_I
  clc
  adc TEXT_ROW
  pha
  lda TEXT_COL_I
  clc
  adc TEXT_COL
  tax
  pla
  ldy TEXT_COLOR
  jsr PixelSet

@rowSkip:
  inc TEXT_ROW_I
  lda TEXT_ROW_I
  cmp #7
  bne @rowLoop

  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp #5
  bne @colLoop

@done:
  rts

FontBitMask:
  .byte $01, $02, $04, $08, $10, $20, $40

; -----------------------------------------------------------------------------
; DrawText - plot a null-terminated string, one glyph every 6 pixels (5 wide
; plus 1 blank column of spacing).
; In:  TEXT_STR_PTR = string pointer, TEXT_ROW/TEXT_COL = origin, TEXT_COLOR
;      Deliberately NOT WORK_PTR -- DrawChar calls down into PixelSet /
;      ComputePixelAddress, which clobbers WORK_PTR for its own shadow-
;      buffer addressing on every pixel, so the string pointer needs its
;      own zero-page home that survives those nested calls.
; Out: TEXT_COL is left just past the string's last character
; Clobbers: A, X, Y, STR_IDX, plus everything DrawChar clobbers
; -----------------------------------------------------------------------------
DrawText:
  stz STR_IDX
@loop:
  ldy STR_IDX
  lda (TEXT_STR_PTR),y
  beq @done
  jsr DrawChar
  lda TEXT_COL
  clc
  adc #6
  sta TEXT_COL
  inc STR_IDX
  jmp @loop
@done:
  rts

; -----------------------------------------------------------------------------
; DrawCharBig - like DrawChar, but each font pixel becomes a 2x2 block
; (10x14 pixels per glyph instead of 5x7), for a title that reads as an
; actual title instead of just another line of body text. Reuses FontData
; as-is rather than needing a second, separately-authored big font.
; In:  A = ASCII character code (space through 'Z')
;      TEXT_ROW/TEXT_COL = top-left pixel origin, TEXT_COLOR = TMS_* color
; Out: none
; Clobbers: A, X, Y, FONT_PTR, FONT_TMP, FONT_HI, TEXT_ROW_I, TEXT_COL_I,
;   SCAN_TMP, SCAN_TMP2
; -----------------------------------------------------------------------------
DrawCharBig:
  cmp #' '
  bcc @done
  cmp #('Z'+1)
  bcs @done

  sec
  sbc #' '
  sta FONT_TMP
  asl a
  asl a
  clc
  adc FONT_TMP
  stz FONT_HI
  bcc @noHi
  inc FONT_HI
@noHi:

  clc
  adc #<FontData
  sta FONT_PTR
  lda FONT_HI
  adc #>FontData
  sta FONT_PTR+1

  stz TEXT_COL_I
@colLoop:
  ldy TEXT_COL_I
  lda (FONT_PTR),y
  sta FONT_TMP

  stz TEXT_ROW_I
@rowLoop:
  ldx TEXT_ROW_I
  lda FONT_TMP
  and FontBitMask,x
  beq @rowSkip

  lda TEXT_ROW_I               ; SCAN_TMP = scaled absolute row (top of
  asl a                          ; this font pixel's 2x2 block)
  clc
  adc TEXT_ROW
  sta SCAN_TMP
  lda TEXT_COL_I               ; SCAN_TMP2 = scaled absolute col (left
  asl a                          ; of this font pixel's 2x2 block)
  clc
  adc TEXT_COL
  sta SCAN_TMP2

  lda SCAN_TMP
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP
  clc
  adc #1
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

@rowSkip:
  inc TEXT_ROW_I
  lda TEXT_ROW_I
  cmp #7
  bne @rowLoop

  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp #5
  bne @colLoop

@done:
  rts

; -----------------------------------------------------------------------------
; DrawTextBig - DrawText's counterpart for DrawCharBig: one glyph every 12
; pixels (10 wide plus 2 blank columns of spacing) instead of 6.
; In:  TEXT_STR_PTR = string pointer, TEXT_ROW/TEXT_COL = origin, TEXT_COLOR
; Out: TEXT_COL is left just past the string's last character
; -----------------------------------------------------------------------------
DrawTextBig:
  stz STR_IDX
@loop:
  ldy STR_IDX
  lda (TEXT_STR_PTR),y
  beq @done
  jsr DrawCharBig
  lda TEXT_COL
  clc
  adc #12
  sta TEXT_COL
  inc STR_IDX
  jmp @loop
@done:
  rts

; -----------------------------------------------------------------------------
; DrawColorSwatch - fill a small 7x7 pixel block with a solid color, used to
; preview a player's selected trail color on the title screen. 7px to match
; the font's own glyph height, so the swatch reads as sitting on the same
; line as the "P1:"/"P2:" text instead of an arbitrary size. Reuses
; DrawChar's TEXT_ROW_I/TEXT_COL_I as generic loop counters, safe since the
; two routines are never active at the same time.
; In: A = top-left row, X = top-left col, Y = TMS_* color
; Out: none
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, TEXT_ROW_I, TEXT_COL_I, TEXT_COLOR,
;   plus everything PixelSet clobbers
; -----------------------------------------------------------------------------
DrawColorSwatch:
  sta SCAN_TMP               ; origin row
  stx SCAN_TMP2               ; origin col
  sty TEXT_COLOR

  stz TEXT_ROW_I
@rowLoop:
  stz TEXT_COL_I
@colLoop:
  lda TEXT_COL_I
  clc
  adc SCAN_TMP2
  tax                          ; X = this pixel's absolute column
  lda TEXT_ROW_I
  clc
  adc SCAN_TMP                 ; A = this pixel's absolute row
  ldy TEXT_COLOR
  jsr PixelSet

  inc TEXT_COL_I
  lda TEXT_COL_I
  cmp #7
  bne @colLoop

  inc TEXT_ROW_I
  lda TEXT_ROW_I
  cmp #7
  bne @rowLoop
  rts

; -----------------------------------------------------------------------------
; DrawUpTriangle / DrawDownTriangle - a small 5x3 "you can go this way"
; affordance. The color swatches already have an accurate hint in their
; left/right chevrons, since they really are a left/right control; MODE
; is a up/down control, so it gets a matching up/down shape instead of
; reusing the chevrons sideways, which wouldn't actually say "up/down" to
; anyone looking at it.
; In: A = top row, X = left col, Y = color
; Out: none
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, TEXT_COLOR, plus everything
;   PixelSet clobbers
; -----------------------------------------------------------------------------
DrawUpTriangle:
  sta SCAN_TMP               ; top row
  stx SCAN_TMP2               ; left col
  sty TEXT_COLOR

  lda SCAN_TMP                ; row0, col+2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+1
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+2
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+3
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+0
  clc
  adc #2
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+1
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+2
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+3
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+4
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet
  rts

DrawDownTriangle:
  sta SCAN_TMP               ; top row
  stx SCAN_TMP2               ; left col
  sty TEXT_COLOR

  lda SCAN_TMP                ; row0, col+0
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row0, col+1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row0, col+2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row0, col+3
  ldx SCAN_TMP2
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row0, col+4
  ldx SCAN_TMP2
  inx
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+1
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+2
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+3
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+2
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet
  rts

; -----------------------------------------------------------------------------
; DrawLeftTriangle / DrawRightTriangle - a small 3x5 "you can go this way"
; affordance, the same design language as DrawUpTriangle/DrawDownTriangle
; (a solid filled arrowhead coming to a single-pixel point, not the font's
; thin </> glyphs) rotated 90 degrees, for a left/right control -- the
; color swatches. DrawTitleScreen centers this against an 8x8 swatch
; (even height, so a perfect pixel-exact center isn't possible against a
; 5-tall odd shape -- it lands within half a pixel, which reads as
; centered) rather than trying to size the triangle to match the swatch
; 1-for-1, which is what previously flattened its point into an edge.
; In: A = top row, X = left col, Y = color
; Out: none
; Clobbers: A, X, Y, SCAN_TMP, SCAN_TMP2, TEXT_COLOR, plus everything
;   PixelSet clobbers
; -----------------------------------------------------------------------------
DrawLeftTriangle:
  sta SCAN_TMP               ; top row
  stx SCAN_TMP2               ; left col
  sty TEXT_COLOR

  lda SCAN_TMP                ; row0, col+2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+1
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+2
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+0
  clc
  adc #2
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+1
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+2
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row3, col+1
  clc
  adc #3
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row3, col+2
  clc
  adc #3
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row4, col+2
  clc
  adc #4
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet
  rts

DrawRightTriangle:
  sta SCAN_TMP               ; top row
  stx SCAN_TMP2               ; left col
  sty TEXT_COLOR

  lda SCAN_TMP                ; row0, col+0
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+0
  clc
  adc #1
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row1, col+1
  clc
  adc #1
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+0
  clc
  adc #2
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+1
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row2, col+2
  clc
  adc #2
  ldx SCAN_TMP2
  inx
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row3, col+0
  clc
  adc #3
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row3, col+1
  clc
  adc #3
  ldx SCAN_TMP2
  inx
  ldy TEXT_COLOR
  jsr PixelSet

  lda SCAN_TMP                ; row4, col+0
  clc
  adc #4
  ldx SCAN_TMP2
  ldy TEXT_COLOR
  jsr PixelSet
  rts
