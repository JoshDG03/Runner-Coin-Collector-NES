; ============================================================
; Enemy system
; ============================================================
;
; The enemy is a 2x2 animated metasprite that uses partner artwork
; copied from AnimationWithInput/wizard.chr into merged sprite tiles
; $20-$3B. It uses sprite palette 3 so it is visually separate from
; the player.
;
; Update flow:
;   1. InitializeEnemy sets a fixed valid spawn position.
;   2. UpdateEnemy runs a slower timer than the player.
;   3. DetermineEnemyChaseDirection picks a primary direction toward
;      the player's current position.
;   4. AttemptEnemyMovement tries that primary axis first.
;   5. If blocked by the map, it tries the other axis.
;   6. DrawEnemySprites appends four enemy sprites after the player
;      sprites in the OAM buffer.

ENEMY_ATTR_NORMAL       = $03
ENEMY_ATTR_HFLIP        = $43
ENEMY_MOVE_SPEED_TICKS  = $10

ENEMY_DIRECTION_RIGHT = $00
ENEMY_DIRECTION_DOWN  = $01
ENEMY_DIRECTION_LEFT  = $02
ENEMY_DIRECTION_UP    = $03

ENEMY_FRAME_DOWN_IDLE  = $00
ENEMY_FRAME_DOWN_A     = $01
ENEMY_FRAME_DOWN_B     = $02
ENEMY_FRAME_UP_IDLE    = $03
ENEMY_FRAME_UP_B       = $04
ENEMY_FRAME_RIGHT_IDLE = $05
ENEMY_FRAME_RIGHT_B    = $06

.segment "ZEROPAGE"
enemyX:               .res 1
enemyY:               .res 1
enemyDirection:       .res 1
enemyMoveTimer:       .res 1
enemyAnimFrame:       .res 1
enemyDrawFrame:       .res 1
enemyDrawAttr:        .res 1
enemyTileTopLeft:     .res 1
enemyTileTopRight:    .res 1
enemyTileBottomLeft:  .res 1
enemyTileBottomRight: .res 1
enemyCandidateX:      .res 1
enemyCandidateY:      .res 1
enemyCollisionResult: .res 1

.segment "CODE"

; ------------------------------------------------------------
; InitializeEnemy
; ------------------------------------------------------------
; Purpose:
;   Sets the enemy start state.
;
; Inputs:
;   None.
;
; Outputs:
;   enemyX = $80
;   enemyY = $70
;   enemyDirection = ENEMY_DIRECTION_LEFT
;   enemyMoveTimer = 0
;   enemyAnimFrame = 0
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   None.
;
; Variables written:
;   enemyX, enemyY, enemyDirection, enemyMoveTimer, enemyAnimFrame,
;   enemyCollisionResult, enemyDrawFrame, enemyDrawAttr
;
; Assumptions:
;   Position $80,$70 is visible, not on top of the player, and begins
;   on a walkable metatile in the current test collision setup.
;
; Side effects:
;   None beyond initializing enemy state.
; ------------------------------------------------------------
.proc InitializeEnemy
  LDA #$80
  STA enemyX
  LDA #$70
  STA enemyY

  LDA #ENEMY_DIRECTION_LEFT
  STA enemyDirection

  LDA #$00
  STA enemyMoveTimer
  STA enemyAnimFrame
  STA enemyDrawFrame
  STA enemyDrawAttr
  STA enemyCollisionResult
  RTS
.endproc

; ------------------------------------------------------------
; UpdateEnemy
; ------------------------------------------------------------
; Purpose:
;   Runs the enemy chase update at a slower fixed rate than the
;   player. Drawing happens separately every frame.
;
; Inputs:
;   player_x, player_y are the target position.
;
; Outputs:
;   enemyX/enemyY may change by 1 pixel when movement is allowed.
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   enemyMoveTimer, player_x, player_y, enemyX, enemyY
;
; Variables written:
;   enemyMoveTimer, enemyDirection, enemyCandidateX, enemyCandidateY,
;   enemyCollisionResult, enemyX, enemyY
;
; Assumptions:
;   Called once per frame from the main loop.
;
; Side effects:
;   Calls collision routines through CheckEnemyCandidatePosition.
; ------------------------------------------------------------
.proc UpdateEnemy
  INC enemyMoveTimer
  LDA enemyMoveTimer
  CMP #ENEMY_MOVE_SPEED_TICKS
  BNE enemy_update_done

  LDA #$00
  STA enemyMoveTimer

  LDA enemyAnimFrame
  EOR #$01
  STA enemyAnimFrame

  JSR DetermineEnemyChaseDirection
  JSR AttemptEnemyMovement

enemy_update_done:
  RTS
.endproc

; ------------------------------------------------------------
; DetermineEnemyChaseDirection
; ------------------------------------------------------------
; Purpose:
;   Chooses a primary chase direction by comparing enemy position
;   against player position. Horizontal movement is preferred when
;   X differs; vertical movement is preferred only when X matches.
;
; Inputs:
;   player_x, player_y, enemyX, enemyY
;
; Outputs:
;   enemyDirection = RIGHT, LEFT, DOWN, or UP
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   player_x, player_y, enemyX, enemyY
;
; Variables written:
;   enemyDirection
;
; Assumptions:
;   Enemy only needs simple pursuit, not pathfinding.
;
; Side effects:
;   None beyond writing enemyDirection.
; ------------------------------------------------------------
.proc DetermineEnemyChaseDirection
  LDA player_x
  CMP enemyX
  BEQ choose_enemy_vertical_direction
  BCC choose_enemy_left_direction

choose_enemy_right_direction:
  LDA #ENEMY_DIRECTION_RIGHT
  STA enemyDirection
  RTS

choose_enemy_left_direction:
  LDA #ENEMY_DIRECTION_LEFT
  STA enemyDirection
  RTS

choose_enemy_vertical_direction:
  LDA player_y
  CMP enemyY
  BEQ keep_enemy_current_direction
  BCC choose_enemy_up_direction

choose_enemy_down_direction:
  LDA #ENEMY_DIRECTION_DOWN
  STA enemyDirection
  RTS

choose_enemy_up_direction:
  LDA #ENEMY_DIRECTION_UP
  STA enemyDirection

keep_enemy_current_direction:
  RTS
.endproc

; ------------------------------------------------------------
; AttemptEnemyMovement
; ------------------------------------------------------------
; Purpose:
;   Attempts to move in the primary chase direction. If blocked, it
;   tries the other axis as a simple fallback.
;
; Inputs:
;   enemyDirection, player_x, player_y, enemyX, enemyY
;
; Outputs:
;   enemyX/enemyY may change by 1 pixel.
;   enemyCollisionResult contains the last attempted collision result.
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   enemyDirection and chase positions
;
; Variables written:
;   enemyCandidateX, enemyCandidateY, enemyCollisionResult,
;   enemyX, enemyY
;
; Assumptions:
;   Collision result $00 means allowed, non-zero means blocked.
;
; Side effects:
;   None beyond movement and collision scratch variables.
; ------------------------------------------------------------
.proc AttemptEnemyMovement
  LDA enemyDirection
  CMP #ENEMY_DIRECTION_RIGHT
  BEQ attempt_primary_horizontal
  CMP #ENEMY_DIRECTION_LEFT
  BEQ attempt_primary_horizontal

attempt_primary_vertical:
  JSR TryEnemyVerticalMovement
  LDA enemyCollisionResult
  BEQ enemy_movement_done
  JSR TryEnemyHorizontalMovement
  RTS

attempt_primary_horizontal:
  JSR TryEnemyHorizontalMovement
  LDA enemyCollisionResult
  BEQ enemy_movement_done
  JSR TryEnemyVerticalMovement

enemy_movement_done:
  RTS
.endproc

; ------------------------------------------------------------
; TryEnemyHorizontalMovement
; ------------------------------------------------------------
; Purpose:
;   Builds and tests a horizontal enemy candidate movement toward
;   player_x. If it is not blocked, commits the new enemy position.
;
; Inputs:
;   player_x, enemyX, enemyY
;
; Outputs:
;   enemyX may move left or right by 1 pixel.
;   enemyCollisionResult is set by CheckEnemyCandidatePosition.
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   player_x, enemyX, enemyY
;
; Variables written:
;   enemyCandidateX, enemyCandidateY, enemyCollisionResult, enemyX,
;   enemyY
;
; Assumptions:
;   If player_x equals enemyX, there is no horizontal movement to try.
;
; Side effects:
;   Calls CheckEnemyCandidatePosition.
; ------------------------------------------------------------
.proc TryEnemyHorizontalMovement
  LDA enemyX
  STA enemyCandidateX
  LDA enemyY
  STA enemyCandidateY

  LDA player_x
  CMP enemyX
  BEQ horizontal_not_needed
  BCC move_enemy_left_candidate

move_enemy_right_candidate:
  INC enemyCandidateX
  JMP test_enemy_horizontal_candidate

move_enemy_left_candidate:
  DEC enemyCandidateX

test_enemy_horizontal_candidate:
  JSR CheckEnemyCandidatePosition
  LDA enemyCollisionResult
  BNE horizontal_done

  LDA enemyCandidateX
  STA enemyX
  LDA enemyCandidateY
  STA enemyY
  RTS

horizontal_not_needed:
  LDA #COLLISION_BLOCKED
  STA enemyCollisionResult

horizontal_done:
  RTS
.endproc

; ------------------------------------------------------------
; TryEnemyVerticalMovement
; ------------------------------------------------------------
; Purpose:
;   Builds and tests a vertical enemy candidate movement toward
;   player_y. If it is not blocked, commits the new enemy position.
;
; Inputs:
;   player_y, enemyX, enemyY
;
; Outputs:
;   enemyY may move up or down by 1 pixel.
;   enemyCollisionResult is set by CheckEnemyCandidatePosition.
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   player_y, enemyX, enemyY
;
; Variables written:
;   enemyCandidateX, enemyCandidateY, enemyCollisionResult, enemyX,
;   enemyY
;
; Assumptions:
;   If player_y equals enemyY, there is no vertical movement to try.
;
; Side effects:
;   Calls CheckEnemyCandidatePosition.
; ------------------------------------------------------------
.proc TryEnemyVerticalMovement
  LDA enemyX
  STA enemyCandidateX
  LDA enemyY
  STA enemyCandidateY

  LDA player_y
  CMP enemyY
  BEQ vertical_not_needed
  BCC move_enemy_up_candidate

move_enemy_down_candidate:
  INC enemyCandidateY
  JMP test_enemy_vertical_candidate

move_enemy_up_candidate:
  DEC enemyCandidateY

test_enemy_vertical_candidate:
  JSR CheckEnemyCandidatePosition
  LDA enemyCollisionResult
  BNE vertical_done

  LDA enemyCandidateX
  STA enemyX
  LDA enemyCandidateY
  STA enemyY
  RTS

vertical_not_needed:
  LDA #COLLISION_BLOCKED
  STA enemyCollisionResult

vertical_done:
  RTS
.endproc

; ------------------------------------------------------------
; CheckEnemyCandidatePosition
; ------------------------------------------------------------
; Purpose:
;   Reuses the existing 16x16 map collision routine for the enemy by
;   copying enemy candidate coordinates into the shared candidate
;   collision variables.
;
; Inputs:
;   enemyCandidateX, enemyCandidateY
;
; Outputs:
;   enemyCollisionResult = collisionResult from the shared checker
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Variables read:
;   enemyCandidateX, enemyCandidateY
;
; Variables written:
;   candidatePlayerX, candidatePlayerY, collisionResult,
;   enemyCollisionResult, collision scratch variables
;
; Assumptions:
;   Enemy and player are both 16x16 metasprites, so the same hitbox
;   logic is acceptable for this first enemy system.
;
; Side effects:
;   Overwrites shared candidate collision variables. This is safe
;   because player and enemy updates run sequentially in the main loop.
; ------------------------------------------------------------
.proc CheckEnemyCandidatePosition
  LDA enemyCandidateX
  STA candidatePlayerX
  LDA enemyCandidateY
  STA candidatePlayerY

  JSR IsPlayerCandidatePositionBlocked
  LDA collisionResult
  STA enemyCollisionResult
  RTS
.endproc

; ------------------------------------------------------------
; ChooseEnemyAnimationFrame
; ------------------------------------------------------------
; Purpose:
;   Chooses which partner-art animation frame to draw based on the
;   enemy direction and the enemyAnimFrame toggle. Left movement uses
;   the right-facing tiles with horizontal flip, matching the original
;   AnimationWithInput approach.
;
; Inputs:
;   enemyDirection, enemyAnimFrame
;
; Outputs:
;   enemyDrawFrame = frame table index
;   enemyDrawAttr = sprite attributes, including palette and flip
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Variables read:
;   enemyDirection, enemyAnimFrame
;
; Variables written:
;   enemyDrawFrame, enemyDrawAttr
;
; Assumptions:
;   The enemy frame table uses the same order as the original partner
;   file: down idle/A/B, up idle/B, right idle/B.
;
; Side effects:
;   None besides selecting draw state.
; ------------------------------------------------------------
.proc ChooseEnemyAnimationFrame
  LDA #ENEMY_ATTR_NORMAL
  STA enemyDrawAttr

  LDA enemyDirection
  CMP #ENEMY_DIRECTION_RIGHT
  BEQ choose_enemy_right_frame
  CMP #ENEMY_DIRECTION_DOWN
  BEQ choose_enemy_down_frame
  CMP #ENEMY_DIRECTION_LEFT
  BEQ choose_enemy_left_frame
  JMP choose_enemy_up_frame

choose_enemy_right_frame:
  LDA enemyAnimFrame
  BEQ choose_enemy_right_idle
  LDA #ENEMY_FRAME_RIGHT_B
  STA enemyDrawFrame
  RTS

choose_enemy_right_idle:
  LDA #ENEMY_FRAME_RIGHT_IDLE
  STA enemyDrawFrame
  RTS

choose_enemy_left_frame:
  LDA #ENEMY_ATTR_HFLIP
  STA enemyDrawAttr

  LDA enemyAnimFrame
  BEQ choose_enemy_left_idle
  LDA #ENEMY_FRAME_RIGHT_B
  STA enemyDrawFrame
  RTS

choose_enemy_left_idle:
  LDA #ENEMY_FRAME_RIGHT_IDLE
  STA enemyDrawFrame
  RTS

choose_enemy_down_frame:
  LDA enemyAnimFrame
  BEQ choose_enemy_down_a
  LDA #ENEMY_FRAME_DOWN_B
  STA enemyDrawFrame
  RTS

choose_enemy_down_a:
  LDA #ENEMY_FRAME_DOWN_A
  STA enemyDrawFrame
  RTS

choose_enemy_up_frame:
  LDA enemyAnimFrame
  BEQ choose_enemy_up_idle
  LDA #ENEMY_FRAME_UP_B
  STA enemyDrawFrame
  RTS

choose_enemy_up_idle:
  LDA #ENEMY_FRAME_UP_IDLE
  STA enemyDrawFrame
  RTS
.endproc

; ------------------------------------------------------------
; LoadEnemyFrameTiles
; ------------------------------------------------------------
; Purpose:
;   Loads the four tile IDs for enemyDrawFrame from enemyFrameTiles.
;   If the enemy is facing left, the left/right tiles are swapped so
;   horizontal flip draws the 2x2 metasprite in the correct order.
;
; Inputs:
;   enemyDrawFrame, enemyDrawAttr
;
; Outputs:
;   enemyTileTopLeft, enemyTileTopRight, enemyTileBottomLeft,
;   enemyTileBottomRight
;
; Registers used:
;   A, X
;
; Registers modified:
;   A, X
;
; Variables read:
;   enemyDrawFrame, enemyDrawAttr, enemyFrameTiles
;
; Variables written:
;   enemyTileTopLeft, enemyTileTopRight, enemyTileBottomLeft,
;   enemyTileBottomRight
;
; Assumptions:
;   enemyFrameTiles has four tile IDs per frame.
;
; Side effects:
;   None besides writing enemy tile scratch variables.
; ------------------------------------------------------------
.proc LoadEnemyFrameTiles
  LDA enemyDrawFrame
  ASL A
  ASL A
  TAX

  LDA enemyFrameTiles, X
  STA enemyTileTopLeft
  INX
  LDA enemyFrameTiles, X
  STA enemyTileTopRight
  INX
  LDA enemyFrameTiles, X
  STA enemyTileBottomLeft
  INX
  LDA enemyFrameTiles, X
  STA enemyTileBottomRight

  LDA enemyDrawAttr
  AND #$40
  BEQ enemy_tiles_loaded

  LDA enemyTileTopLeft
  PHA
  LDA enemyTileTopRight
  STA enemyTileTopLeft
  PLA
  STA enemyTileTopRight

  LDA enemyTileBottomLeft
  PHA
  LDA enemyTileBottomRight
  STA enemyTileBottomLeft
  PLA
  STA enemyTileBottomRight

enemy_tiles_loaded:
  RTS
.endproc

; ------------------------------------------------------------
; DrawEnemySprites
; ------------------------------------------------------------
; Purpose:
;   Appends a 2x2 animated enemy metasprite to the OAM buffer after
;   whatever sprites have already been written. The player draw
;   routine leaves oam_ptr pointing after the player sprites.
;
; Inputs:
;   enemyX, enemyY, enemyDirection, enemyAnimFrame, oam_ptr
;
; Outputs:
;   Four sprites are written to $0200 OAM buffer.
;   oam_ptr advances by 16 bytes.
;
; Registers used:
;   A, X
;
; Registers modified:
;   A, X
;
; Variables read:
;   enemyX, enemyY, enemyDirection, enemyAnimFrame, oam_ptr
;
; Variables written:
;   $0200-$02FF OAM buffer, oam_ptr, enemy draw scratch variables
;
; Assumptions:
;   clear_oam_buffer ran earlier this frame, and draw_character ran
;   before this routine so oam_ptr points after the player sprites.
;
; Side effects:
;   Writes sprite OAM data only; the actual DMA still happens in
;   ppu_commit.
; ------------------------------------------------------------
.proc DrawEnemySprites
  JSR ChooseEnemyAnimationFrame
  JSR LoadEnemyFrameTiles

  LDX oam_ptr

  LDA enemyY
  STA $0200, X
  LDA enemyTileTopLeft
  STA $0201, X
  LDA enemyDrawAttr
  STA $0202, X
  LDA enemyX
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA enemyY
  STA $0200, X
  LDA enemyTileTopRight
  STA $0201, X
  LDA enemyDrawAttr
  STA $0202, X
  LDA enemyX
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA enemyY
  CLC
  ADC #$08
  STA $0200, X
  LDA enemyTileBottomLeft
  STA $0201, X
  LDA enemyDrawAttr
  STA $0202, X
  LDA enemyX
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA enemyY
  CLC
  ADC #$08
  STA $0200, X
  LDA enemyTileBottomRight
  STA $0201, X
  LDA enemyDrawAttr
  STA $0202, X
  LDA enemyX
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  STX oam_ptr
  RTS
.endproc

.segment "RODATA"

; Partner wizard frames copied from AnimationWithInput/Activity4Parte2.asm.
; These tile IDs point to the merged destination copies in sprites.chr:
;   original $04-$07 -> merged $20-$23  DOWN_IDLE
;   original $08-$0B -> merged $24-$27  DOWN_A
;   original $0C-$0F -> merged $28-$2B  DOWN_B
;   original $18-$1B -> merged $2C-$2F  UP_IDLE
;   original $1C-$1F -> merged $30-$33  UP_B
;   original $10-$13 -> merged $34-$37  RIGHT_IDLE
;   original $14-$17 -> merged $38-$3B  RIGHT_B
enemyFrameTiles:
  .byte $20,$21,$22,$23
  .byte $24,$25,$26,$27
  .byte $28,$29,$2A,$2B
  .byte $2C,$2D,$2E,$2F
  .byte $30,$31,$32,$33
  .byte $34,$35,$36,$37
  .byte $38,$39,$3A,$3B
