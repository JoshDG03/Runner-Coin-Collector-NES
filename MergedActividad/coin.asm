COIN_TILE_ID                 = $3C
COIN_ATTR                    = $02
PLAYER_INITIAL_SPEED_TICKS   = $06
PLAYER_MIN_SPEED_TICKS       = $02
ENEMY_INITIAL_SPEED_TICKS    = $08
ENEMY_MIN_SPEED_TICKS        = $04
COIN_DRAW_OFFSET             = $04

.segment "ZEROPAGE"
coinX:               .res 1
coinY:               .res 1
coinMetatileColumn:  .res 1
coinMetatileRow:     .res 1
coinRandom:          .res 1
coinSpawnColumn:     .res 1
coinSpawnRow:        .res 1
coinCenterX:         .res 1
coinCenterY:         .res 1
playerMoveSpeedTicks:.res 1
enemyMoveSpeedTicks: .res 1

.segment "CODE"

.proc InitCoinSystem
  LDA #$5D
  STA coinRandom

  LDA #PLAYER_INITIAL_SPEED_TICKS
  STA playerMoveSpeedTicks

  LDA #ENEMY_INITIAL_SPEED_TICKS
  STA enemyMoveSpeedTicks

  JSR SpawnCoin
  RTS
.endproc

.proc AdvanceCoinRandom
  LDA coinRandom
  ASL A
  BCC no_random_feedback
  EOR #$1D

no_random_feedback:
  EOR player_x
  EOR enemyY
  STA coinRandom
  RTS
.endproc

.proc SpawnCoin
spawn_coin_loop:
  JSR AdvanceCoinRandom
  LDA coinRandom
  AND #$0F
  STA coinSpawnColumn

  JSR AdvanceCoinRandom
  LDA coinRandom
  AND #$0F
  CMP #$0F
  BEQ spawn_coin_loop
  STA coinSpawnRow

  LDA coinSpawnColumn
  STA metatileColumn
  LDA coinSpawnRow
  STA metatileRow
  JSR ReadMetatileAtMapCoordinate
  JSR IsMetatileSolid
  LDA collisionResult
  BNE spawn_coin_loop

  LDA player_x
  LSR A
  LSR A
  LSR A
  LSR A
  CMP coinSpawnColumn
  BNE check_enemy_spawn_overlap

  LDA player_y
  LSR A
  LSR A
  LSR A
  LSR A
  CMP coinSpawnRow
  BEQ spawn_coin_loop

check_enemy_spawn_overlap:
  LDA enemyX
  LSR A
  LSR A
  LSR A
  LSR A
  CMP coinSpawnColumn
  BNE commit_coin_spawn

  LDA enemyY
  LSR A
  LSR A
  LSR A
  LSR A
  CMP coinSpawnRow
  BEQ spawn_coin_loop

commit_coin_spawn:
  LDA coinSpawnColumn
  STA coinMetatileColumn
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC #COIN_DRAW_OFFSET
  STA coinX

  LDA coinSpawnRow
  STA coinMetatileRow
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC #COIN_DRAW_OFFSET
  STA coinY
  RTS
.endproc

.proc CheckCoinCollected
  LDA player_x
  STA candidatePlayerX
  LDA player_y
  STA candidatePlayerY
  JSR BuildCandidatePlayerBounds

  LDA coinX
  CLC
  ADC #$04
  STA coinCenterX

  LDA coinY
  CLC
  ADC #$04
  STA coinCenterY

  LDA coinCenterX
  CMP candidateLeft
  BCC coin_not_collected
  CMP candidateRight
  BCC coin_x_inside
  BEQ coin_x_inside
  JMP coin_not_collected

coin_x_inside:
  LDA coinCenterY
  CMP candidateTop
  BCC coin_not_collected
  CMP candidateBottom
  BCC coin_collected
  BEQ coin_collected

coin_not_collected:
  RTS

coin_collected:
  JSR AddScoreTen
  JSR IncreasePlayerSpeed
  JSR IncreaseEnemySpeed
  JSR SpawnCoin
  RTS
.endproc

.proc IncreasePlayerSpeed
  LDA playerMoveSpeedTicks
  CMP #PLAYER_MIN_SPEED_TICKS
  BEQ player_speed_done

  SEC
  SBC #$01
  STA playerMoveSpeedTicks

player_speed_done:
  RTS
.endproc

.proc IncreaseEnemySpeed
  LDA enemyMoveSpeedTicks
  CMP #ENEMY_MIN_SPEED_TICKS
  BEQ enemy_speed_done

  SEC
  SBC #$01
  STA enemyMoveSpeedTicks

enemy_speed_done:
  RTS
.endproc

.proc DrawCoinSprite
  LDX oam_ptr

  LDA coinY
  STA $0200, X
  LDA #COIN_TILE_ID
  STA $0201, X
  LDA #COIN_ATTR
  STA $0202, X
  LDA coinX
  STA $0203, X

  TXA
  CLC
  ADC #$04
  TAX
  STX oam_ptr
  RTS
.endproc
