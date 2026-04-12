HUD_LIVES_HEART_TILE   = $29
HUD_LIVES_X_TILE       = $28
HUD_SCORE_S_TILE       = $22
HUD_SCORE_C_TILE       = $23
HUD_SCORE_O_TILE       = $24
HUD_SCORE_R_TILE       = $25
HUD_SCORE_E_TILE       = $26
HUD_SCORE_COLON_TILE   = $27
HUD_TILE_ZERO          = $0E

HUD_LIVES_HEART_COL    = $01
HUD_LIVES_X_COL        = $02
HUD_LIVES_DIGIT_COL    = $03

HUD_SCORE_LABEL_COL    = $17
HUD_SCORE_HUNDREDS_COL = $1D
HUD_SCORE_TENS_COL     = $1E
HUD_SCORE_ONES_COL     = $1F

HUD_ROW                = $00
HUD_NAMETABLE_BASE_HI  = $20
HUD_ATTR_BASE_HI       = $23
HUD_ATTR_BASE_LO       = $C0

.segment "ZEROPAGE"
livesRemaining:     .res 1
scoreHundredsDigit: .res 1
scoreTensDigit:     .res 1
hudDirty:           .res 1
enemyTouchLatch:    .res 1
entityRightEdge:    .res 1
entityBottomEdge:   .res 1

.segment "CODE"

.proc InitHudSystem
  LDA #$03
  STA livesRemaining

  LDA #$00
  STA scoreHundredsDigit
  STA scoreTensDigit
  STA enemyTouchLatch

  LDA #$01
  STA hudDirty
  RTS
.endproc

.proc DrawHudStatic
  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_LIVES_HEART_COL
  STA PPUADDR
  LDA #HUD_LIVES_HEART_TILE
  STA PPUDATA
  LDA #HUD_LIVES_X_TILE
  STA PPUDATA

  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_SCORE_LABEL_COL
  STA PPUADDR
  LDA #HUD_SCORE_S_TILE
  STA PPUDATA
  LDA #HUD_SCORE_C_TILE
  STA PPUDATA
  LDA #HUD_SCORE_O_TILE
  STA PPUDATA
  LDA #HUD_SCORE_R_TILE
  STA PPUDATA
  LDA #HUD_SCORE_E_TILE
  STA PPUDATA
  LDA #HUD_SCORE_COLON_TILE
  STA PPUDATA

  JSR ApplyHudAttributes
  RTS
.endproc

.proc ApplyHudAttributes
  ; Top-left HUD area:
  ; cols 0-1 use background palette 2 for the heart, cols 2-3 use palette 3.
  LDA PPUSTATUS
  LDA #HUD_ATTR_BASE_HI
  STA PPUADDR
  LDA #HUD_ATTR_BASE_LO
  STA PPUADDR
  LDA #$CE
  STA PPUDATA

  ; Score label begins in attribute byte 5 and continues through 7.
  LDA PPUSTATUS
  LDA #HUD_ATTR_BASE_HI
  STA PPUADDR
  LDA #(HUD_ATTR_BASE_LO + $05)
  STA PPUADDR
  LDA #$CC
  STA PPUDATA
  LDA #$EF
  STA PPUDATA
  LDA #$3F
  STA PPUDATA
  RTS
.endproc

.proc UpdateHudDynamic
  JSR DrawLivesDigits
  JSR DrawScoreDigits

  LDA #$00
  STA hudDirty

  LDA PPUSTATUS
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL
  RTS
.endproc

.proc DrawLivesDigits
  LDA livesRemaining
  JSR ConvertDigitToTile

  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_LIVES_DIGIT_COL
  STA PPUADDR
  LDA digitTileBuffer
  STA PPUDATA
  RTS
.endproc

.proc DrawScoreDigits
  LDA scoreHundredsDigit
  JSR ConvertDigitToTile

  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_SCORE_HUNDREDS_COL
  STA PPUADDR
  LDA digitTileBuffer
  STA PPUDATA

  LDA scoreTensDigit
  JSR ConvertDigitToTile

  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_SCORE_TENS_COL
  STA PPUADDR
  LDA digitTileBuffer
  STA PPUDATA

  LDA #HUD_TILE_ZERO
  STA digitTileBuffer

  LDA PPUSTATUS
  LDA #HUD_NAMETABLE_BASE_HI
  STA PPUADDR
  LDA #HUD_SCORE_ONES_COL
  STA PPUADDR
  LDA digitTileBuffer
  STA PPUDATA
  RTS
.endproc

.proc ConvertDigitToTile
  TAX
  LDA digitTileTable, X
  STA digitTileBuffer
  RTS
.endproc

.proc AddScoreTen
  INC scoreTensDigit
  LDA scoreTensDigit
  CMP #$0A
  BNE mark_hud_dirty

  LDA #$00
  STA scoreTensDigit
  INC scoreHundredsDigit

  LDA scoreHundredsDigit
  CMP #$0A
  BNE mark_hud_dirty

  LDA #$00
  STA scoreHundredsDigit

mark_hud_dirty:
  LDA #$01
  STA hudDirty
  RTS
.endproc

.proc CheckEnemyHitPlayer
  ; If player right edge is left of enemy left edge, they do not overlap.
  LDA player_x
  CLC
  ADC #$0F
  CMP enemyX
  BCC player_not_touching_enemy

  ; If enemy right edge is left of player left edge, they do not overlap.
  LDA enemyX
  CLC
  ADC #$0F
  CMP player_x
  BCC player_not_touching_enemy

  ; If player bottom edge is above enemy top edge, they do not overlap.
  LDA player_y
  CLC
  ADC #$0F
  CMP enemyY
  BCC player_not_touching_enemy

  ; If enemy bottom edge is above player top edge, they do not overlap.
  LDA enemyY
  CLC
  ADC #$0F
  CMP player_y
  BCC player_not_touching_enemy

  LDA enemyTouchLatch
  BNE enemy_touch_done

  LDA #$01
  STA enemyTouchLatch
  JSR LoseOneLife
  RTS

player_not_touching_enemy:
  LDA #$00
  STA enemyTouchLatch

enemy_touch_done:
  RTS
.endproc

.proc LoseOneLife
  LDA livesRemaining
  BEQ no_lives_left

  SEC
  SBC #$01
  STA livesRemaining

  LDA #$01
  STA hudDirty

no_lives_left:
  RTS
.endproc

.segment "RODATA"
digitTileTable:
  .byte $0E,$0F,$10,$11,$12,$13,$1E,$1F,$20,$21

.segment "ZEROPAGE"
digitTileBuffer: .res 1
