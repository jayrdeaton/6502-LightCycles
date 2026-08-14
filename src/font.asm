; ============================================================
; font.asm - 5x7 pixel bitmap font for LightCycles (TMS9918 Graphics II)
; ============================================================
; FontData is a dense table covering ASCII $20 (space) through $5A ('Z')
; inclusive, 5 bytes per glyph, in ascending ASCII order with no gaps.
;
; To look up a glyph for character C (where C is in $20..$5A):
;     offset = (C - $20) * 5
;   FontData+offset .. FontData+offset+4 are the glyph's 5 column bytes.
;
; Each glyph is 5 pixels wide x 7 pixels tall, stored as 5 consecutive
; bytes - one byte per COLUMN, left column first (col0, col1, col2,
; col3, col4).
;
; Within each column byte, bits correspond to rows top-to-bottom:
;   bit0 (value $01) = row 0 (TOP row of the glyph)
;   bit1 (value $02) = row 1
;   bit2 (value $04) = row 2
;   bit3 (value $08) = row 3
;   bit4 (value $10) = row 4
;   bit5 (value $20) = row 5
;   bit6 (value $40) = row 6 (BOTTOM row of the glyph)
;   bit7             = unused, always 0
;
; So every byte in this table is in the range $00-$7F.
;
; Example - capital 'A':
;   .XXX.
;   X...X
;   X...X
;   XXXXX
;   X...X
;   X...X
;   X...X
; encodes as: .byte $7E, $09, $09, $09, $7E
;
; Characters that have no clear standard 5x7 glyph, or that this game
; will never plausibly display (# $ % & * @), are left blank (all
; zero bytes) rather than inventing an arbitrary shape for them.
; ============================================================

FontData:
        ; $20 ' ' (space)
        .byte $00, $00, $00, $00, $00
        ; $21 '!'
        .byte $00, $00, $5F, $00, $00
        ; $22 '"'
        .byte $00, $03, $00, $03, $00
        ; $23 '#' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $24 '$' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $25 '%' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $26 '&' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $27 '''
        .byte $00, $00, $03, $00, $00
        ; $28 '('
        .byte $00, $1C, $22, $41, $00
        ; $29 ')'
        .byte $00, $41, $22, $1C, $00
        ; $2A '*' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $2B '+'
        .byte $08, $08, $3E, $08, $08
        ; $2C ','
        .byte $00, $40, $20, $00, $00
        ; $2D '-'
        .byte $08, $08, $08, $08, $08
        ; $2E '.'
        .byte $00, $00, $40, $00, $00
        ; $2F '/'
        .byte $60, $10, $08, $04, $03
        ; $30 '0'
        .byte $3E, $51, $49, $45, $3E
        ; $31 '1'
        .byte $00, $42, $7F, $40, $00
        ; $32 '2'
        .byte $42, $61, $51, $49, $46
        ; $33 '3'
        .byte $22, $41, $49, $49, $36
        ; $34 '4'
        .byte $18, $14, $12, $7F, $10
        ; $35 '5'
        .byte $27, $45, $45, $45, $39
        ; $36 '6'
        .byte $3C, $4A, $49, $49, $30
        ; $37 '7'
        .byte $01, $71, $09, $05, $03
        ; $38 '8'
        .byte $36, $49, $49, $49, $36
        ; $39 '9'
        .byte $06, $49, $49, $29, $1E
        ; $3A ':' -- 2x2 dots (not 1x1) so it survives display scaling;
        ; a single isolated pixel was getting lost entirely on screen
        .byte $00, $36, $36, $00, $00
        ; $3B ';'
        .byte $00, $40, $34, $00, $00
        ; $3C '<'
        .byte $00, $08, $14, $22, $41
        ; $3D '='
        .byte $14, $14, $14, $14, $14
        ; $3E '>'
        .byte $41, $22, $14, $08, $00
        ; $3F '?'
        .byte $02, $01, $51, $09, $06
        ; $40 '@' (blank - not used by this game)
        .byte $00, $00, $00, $00, $00
        ; $41 'A'
        .byte $7E, $09, $09, $09, $7E
        ; $42 'B'
        .byte $7F, $49, $49, $49, $36
        ; $43 'C'
        .byte $3E, $41, $41, $41, $22
        ; $44 'D'
        .byte $7F, $41, $41, $41, $3E
        ; $45 'E'
        .byte $7F, $49, $49, $49, $41
        ; $46 'F'
        .byte $7F, $09, $09, $09, $01
        ; $47 'G'
        .byte $3E, $41, $49, $49, $3A
        ; $48 'H'
        .byte $7F, $08, $08, $08, $7F
        ; $49 'I'
        .byte $41, $41, $7F, $41, $41
        ; $4A 'J'
        .byte $30, $40, $40, $40, $3F
        ; $4B 'K'
        .byte $7F, $08, $14, $22, $41
        ; $4C 'L'
        .byte $7F, $40, $40, $40, $40
        ; $4D 'M'
        .byte $7F, $02, $04, $02, $7F
        ; $4E 'N'
        .byte $7F, $02, $0C, $10, $7F
        ; $4F 'O'
        .byte $3E, $41, $41, $41, $3E
        ; $50 'P'
        .byte $7F, $09, $09, $09, $06
        ; $51 'Q'
        .byte $3E, $41, $41, $21, $5E
        ; $52 'R'
        .byte $7F, $09, $19, $29, $46
        ; $53 'S'
        .byte $46, $49, $49, $49, $31
        ; $54 'T'
        .byte $01, $01, $7F, $01, $01
        ; $55 'U'
        .byte $3F, $40, $40, $40, $3F
        ; $56 'V'
        .byte $1F, $20, $40, $20, $1F
        ; $57 'W'
        .byte $3F, $40, $38, $40, $3F
        ; $58 'X'
        .byte $63, $14, $08, $14, $63
        ; $59 'Y'
        .byte $03, $04, $78, $04, $03
        ; $5A 'Z'
        .byte $61, $51, $49, $45, $43
