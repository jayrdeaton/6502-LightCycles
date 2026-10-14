; =============================================================================
;   rng.asm - local bootstrap RNG (to be replaced by 6502-Lib include)
; =============================================================================

.segment "CART"

AdvanceRng:
  lda RNG_STATE
  lsr a
  bcc @noeor
  eor #$B4
@noeor:
  sta RNG_STATE
  rts
