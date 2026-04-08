; ============================================================
; Collision system for the compressed metatile map
; ============================================================
;
; The map is 16 metatiles wide by 15 metatiles tall.
; Each metatile is 16x16 pixels and is stored as a 2-bit value
; inside packed_map. Four metatiles fit in one byte:
;
;   bits 7-6 = column group item 0
;   bits 5-4 = column group item 1
;   bits 3-2 = column group item 2
;   bits 1-0 = column group item 3
;
; Current solidity convention for this map:
;   metatile 0 = solid border/wall
;   metatile 1 = walkable
;   metatile 2 = solid obstacle
;   metatile 3 = walkable
;
; This test setup starts the player on metatile 3 and treats
; metatile 2 as an obstacle so the collision behavior can be checked
; without controller code.
;
; The player art is 16x16 pixels. The collision box uses a small
; inset so the sprite can brush near walls without feeling too wide.

PLAYER_HITBOX_LEFT_INSET   = $02
PLAYER_HITBOX_RIGHT_INSET  = $02
PLAYER_HITBOX_TOP_INSET    = $02
PLAYER_HITBOX_BOTTOM_INSET = $01
PLAYER_VISUAL_WIDTH        = $10
PLAYER_VISUAL_HEIGHT       = $10
COLLISION_ALLOWED          = $00
COLLISION_BLOCKED          = $01

.segment "ZEROPAGE"
candidatePlayerX:   .res 1
candidatePlayerY:   .res 1
candidateLeft:      .res 1
candidateRight:     .res 1
candidateTop:       .res 1
candidateBottom:    .res 1
collisionResult:    .res 1
collisionPixelX:    .res 1
collisionPixelY:    .res 1
metatileColumn:     .res 1
metatileRow:        .res 1
metatileValue:      .res 1
mapPackedByteIndex: .res 1
mapBitPairIndex:    .res 1

.segment "CODE"

; ------------------------------------------------------------
; BuildCandidatePlayerBounds
; ------------------------------------------------------------
; Purpose:
;   Builds a small collision box around the candidate player
;   position. This does not move the player; it only prepares
;   the bounds that the collision checker will test.
;
; Inputs:
;   candidatePlayerX = proposed next player X pixel position
;   candidatePlayerY = proposed next player Y pixel position
;
; Outputs:
;   candidateLeft    = candidatePlayerX + left inset
;   candidateRight   = candidatePlayerX + 15 - right inset
;   candidateTop     = candidatePlayerY + top inset
;   candidateBottom  = candidatePlayerY + 15 - bottom inset
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Memory read:
;   candidatePlayerX, candidatePlayerY
;
; Memory written:
;   candidateLeft, candidateRight, candidateTop, candidateBottom
;
; Assumptions:
;   The player sprite is 16x16 pixels.
;
; Side effects:
;   None besides writing the candidate bounds.
; ------------------------------------------------------------
.proc BuildCandidatePlayerBounds
  LDA candidatePlayerX
  CLC
  ADC #PLAYER_HITBOX_LEFT_INSET
  STA candidateLeft

  LDA candidatePlayerX
  CLC
  ADC #(PLAYER_VISUAL_WIDTH - $01 - PLAYER_HITBOX_RIGHT_INSET)
  STA candidateRight

  LDA candidatePlayerY
  CLC
  ADC #PLAYER_HITBOX_TOP_INSET
  STA candidateTop

  LDA candidatePlayerY
  CLC
  ADC #(PLAYER_VISUAL_HEIGHT - $01 - PLAYER_HITBOX_BOTTOM_INSET)
  STA candidateBottom

  RTS
.endproc

; ------------------------------------------------------------
; ConvertPixelToMetatileColumn
; ------------------------------------------------------------
; Purpose:
;   Converts a horizontal pixel position to a metatile column.
;   Since metatiles are 16 pixels wide, this is pixel / 16.
;
; Inputs:
;   A = pixel X position
;
; Outputs:
;   A = metatile column, 0..15 for on-screen map positions
;   metatileColumn = same value
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Memory read:
;   None
;
; Memory written:
;   metatileColumn
;
; Assumptions:
;   The caller provides a pixel position inside the visible map.
;   Out-of-map values are later treated as blocked by the checker.
;
; Side effects:
;   None besides writing metatileColumn.
; ------------------------------------------------------------
.proc ConvertPixelToMetatileColumn
  LSR A
  LSR A
  LSR A
  LSR A
  STA metatileColumn
  RTS
.endproc

; ------------------------------------------------------------
; ConvertPixelToMetatileRow
; ------------------------------------------------------------
; Purpose:
;   Converts a vertical pixel position to a metatile row.
;   Since metatiles are 16 pixels tall, this is pixel / 16.
;
; Inputs:
;   A = pixel Y position
;
; Outputs:
;   A = metatile row, 0..14 for on-screen map positions
;   metatileRow = same value
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Memory read:
;   None
;
; Memory written:
;   metatileRow
;
; Assumptions:
;   The caller provides a pixel position inside the visible map.
;   Out-of-map values are later treated as blocked by the checker.
;
; Side effects:
;   None besides writing metatileRow.
; ------------------------------------------------------------
.proc ConvertPixelToMetatileRow
  LSR A
  LSR A
  LSR A
  LSR A
  STA metatileRow
  RTS
.endproc

; ------------------------------------------------------------
; GetMetatileAtPixelPosition
; ------------------------------------------------------------
; Purpose:
;   Converts a pixel position to a metatile coordinate, then reads
;   the packed metatile value from packed_map.
;
; Inputs:
;   collisionPixelX = pixel X point to test
;   collisionPixelY = pixel Y point to test
;
; Outputs:
;   A = metatile value, 0..3
;   metatileColumn = pixel X / 16
;   metatileRow = pixel Y / 16
;   metatileValue = metatile value read from the map
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   collisionPixelX, collisionPixelY, packed_map
;
; Memory written:
;   metatileColumn, metatileRow, metatileValue,
;   mapPackedByteIndex, mapBitPairIndex
;
; Assumptions:
;   packed_map has 15 rows. Each row has 4 packed bytes.
;
; Side effects:
;   None besides updating the documented collision scratch variables.
; ------------------------------------------------------------
.proc GetMetatileAtPixelPosition
  LDA collisionPixelX
  JSR ConvertPixelToMetatileColumn

  LDA collisionPixelY
  JSR ConvertPixelToMetatileRow

  JSR ReadMetatileAtMapCoordinate
  RTS
.endproc

; ------------------------------------------------------------
; ReadMetatileAtMapCoordinate
; ------------------------------------------------------------
; Purpose:
;   Reads one metatile ID from the compressed 2-bit map using the
;   already computed metatile row and column.
;
; Inputs:
;   metatileColumn = map column, expected 0..15
;   metatileRow = map row, expected 0..14
;
; Outputs:
;   A = metatile value, 0..3
;   metatileValue = same value
;   If the coordinate is outside the map, A and metatileValue are 0.
;   That makes out-of-map positions solid because metatile 0 is solid.
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   metatileColumn, metatileRow, packed_map
;
; Memory written:
;   metatileValue, mapPackedByteIndex, mapBitPairIndex
;
; Assumptions:
;   Map width is 16 metatiles. Map height is 15 metatiles.
;
; Side effects:
;   None besides updating the documented collision scratch variables.
; ------------------------------------------------------------
.proc ReadMetatileAtMapCoordinate
  LDA metatileColumn
  CMP #$10
  BCS read_outside_map

  LDA metatileRow
  CMP #$0F
  BCS read_outside_map

  LDA metatileColumn
  AND #$03
  STA mapBitPairIndex

  LDA metatileRow
  ASL A
  ASL A
  STA mapPackedByteIndex

  LDA metatileColumn
  LSR A
  LSR A
  CLC
  ADC mapPackedByteIndex
  STA mapPackedByteIndex

  LDY mapPackedByteIndex
  LDA packed_map, Y

  LDY mapBitPairIndex
  CPY #$00
  BEQ extract_bits_7_6
  CPY #$01
  BEQ extract_bits_5_4
  CPY #$02
  BEQ extract_bits_3_2
  JMP extract_bits_1_0

extract_bits_7_6:
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  STA metatileValue
  RTS

extract_bits_5_4:
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  STA metatileValue
  RTS

extract_bits_3_2:
  LSR A
  LSR A
  AND #$03
  STA metatileValue
  RTS

extract_bits_1_0:
  AND #$03
  STA metatileValue
  RTS

read_outside_map:
  LDA #$00
  STA metatileValue
  RTS
.endproc

; ------------------------------------------------------------
; IsMetatileSolid
; ------------------------------------------------------------
; Purpose:
;   Converts a metatile ID into a blocked/allowed result using
;   the current map solidity convention.
;
; Inputs:
;   A = metatile value, 0..3
;
; Outputs:
;   A = COLLISION_BLOCKED if solid
;   A = COLLISION_ALLOWED if walkable
;   collisionResult = same value
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Memory read:
;   None
;
; Memory written:
;   collisionResult
;
; Assumptions:
;   For the current test, metatile 0 is the outer wall and metatile 2
;   is an obstacle. Metatiles 1 and 3 are walkable.
;
; Side effects:
;   None besides writing collisionResult.
; ------------------------------------------------------------
.proc IsMetatileSolid
  CMP #$00
  BEQ metatile_is_solid
  CMP #$02
  BEQ metatile_is_solid

  LDA #COLLISION_ALLOWED
  STA collisionResult
  RTS

metatile_is_solid:
  LDA #COLLISION_BLOCKED
  STA collisionResult
  RTS
.endproc

; ------------------------------------------------------------
; EvaluateCollisionPoint
; ------------------------------------------------------------
; Purpose:
;   Tests one pixel point against the map. The caller places the
;   point into collisionPixelX and collisionPixelY before calling.
;
; Inputs:
;   collisionPixelX = pixel X point to test
;   collisionPixelY = pixel Y point to test
;
; Outputs:
;   A = COLLISION_BLOCKED if the point is inside a solid metatile
;   A = COLLISION_ALLOWED if the point is inside a walkable metatile
;   collisionResult = same value
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   collisionPixelX, collisionPixelY, packed_map
;
; Memory written:
;   collisionResult plus map lookup scratch variables
;
; Assumptions:
;   The map lookup treats out-of-map coordinates as metatile 0,
;   which is solid.
;
; Side effects:
;   None besides updating documented collision variables.
; ------------------------------------------------------------
.proc EvaluateCollisionPoint
  JSR GetMetatileAtPixelPosition
  JSR IsMetatileSolid
  RTS
.endproc

; ------------------------------------------------------------
; CheckPlayerCollisionAtCandidatePosition
; ------------------------------------------------------------
; Purpose:
;   Checks the candidate player's bounding box against the map.
;   This is the main reusable routine movement code should call
;   after it computes candidatePlayerX and candidatePlayerY.
;
; Inputs:
;   candidatePlayerX = proposed next player X
;   candidatePlayerY = proposed next player Y
;
; Outputs:
;   A = COLLISION_BLOCKED if any checked corner hits solid map
;   A = COLLISION_ALLOWED if all checked corners are walkable
;   collisionResult = same value
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidatePlayerX, candidatePlayerY, packed_map
;
; Memory written:
;   candidate bounds, collisionResult, collision point variables,
;   metatile lookup scratch variables
;
; Assumptions:
;   A four-corner test is enough for this 16x16 player against
;   16x16 metatiles because the hitbox is not wider than a metatile.
;
; Side effects:
;   Does not move the player. It only writes collisionResult and
;   scratch variables.
; ------------------------------------------------------------
.proc CheckPlayerCollisionAtCandidatePosition
  JSR BuildCandidatePlayerBounds

  JSR EvaluatePlayerTopLeftCollisionPoint
  LDA collisionResult
  CMP #COLLISION_BLOCKED
  BEQ candidate_position_is_blocked

  JSR EvaluatePlayerTopRightCollisionPoint
  LDA collisionResult
  CMP #COLLISION_BLOCKED
  BEQ candidate_position_is_blocked

  JSR EvaluatePlayerBottomLeftCollisionPoint
  LDA collisionResult
  CMP #COLLISION_BLOCKED
  BEQ candidate_position_is_blocked

  JSR EvaluatePlayerBottomRightCollisionPoint
  LDA collisionResult
  CMP #COLLISION_BLOCKED
  BEQ candidate_position_is_blocked

  LDA #COLLISION_ALLOWED
  STA collisionResult
  RTS

candidate_position_is_blocked:
  LDA #COLLISION_BLOCKED
  STA collisionResult
  RTS
.endproc

; ------------------------------------------------------------
; IsPlayerCandidatePositionBlocked
; ------------------------------------------------------------
; Purpose:
;   Readable wrapper around CheckPlayerCollisionAtCandidatePosition.
;   This exists so movement code can ask the question directly.
;   This is the routine controller movement should call after it
;   computes candidatePlayerX and candidatePlayerY.
;
; Partner/controller merge notes:
;   - Put the proposed next X into candidatePlayerX.
;   - Put the proposed next Y into candidatePlayerY.
;   - JSR IsPlayerCandidatePositionBlocked.
;   - If collisionResult is COLLISION_ALLOWED ($00), movement code
;     may commit the move by copying candidatePlayerX/Y into
;     player_x/player_y.
;   - If collisionResult is COLLISION_BLOCKED ($01), movement code
;     should reject the move and leave player_x/player_y unchanged.
;   - This routine does not read the controller and does not move the
;     player by itself. That keeps it reusable.
;
; Inputs:
;   candidatePlayerX = proposed next player X
;   candidatePlayerY = proposed next player Y
;
; Outputs:
;   A = COLLISION_BLOCKED or COLLISION_ALLOWED
;   collisionResult = same value
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidatePlayerX, candidatePlayerY, packed_map
;
; Memory written:
;   collisionResult and collision scratch variables
;
; Assumptions:
;   Same as CheckPlayerCollisionAtCandidatePosition.
;
; Side effects:
;   Does not move the player.
; ------------------------------------------------------------
.proc IsPlayerCandidatePositionBlocked
  JSR CheckPlayerCollisionAtCandidatePosition
  RTS
.endproc

; ------------------------------------------------------------
; EvaluatePlayerTopLeftCollisionPoint
; ------------------------------------------------------------
; Purpose:
;   Tests the top-left corner of the candidate hitbox.
;
; Inputs:
;   candidateLeft, candidateTop
;
; Outputs:
;   A and collisionResult are blocked/allowed.
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidateLeft, candidateTop
;
; Memory written:
;   collisionPixelX, collisionPixelY, collisionResult,
;   map lookup scratch variables
;
; Assumptions:
;   BuildCandidatePlayerBounds has already run.
;
; Side effects:
;   None besides documented collision scratch writes.
; ------------------------------------------------------------
.proc EvaluatePlayerTopLeftCollisionPoint
  LDA candidateLeft
  STA collisionPixelX
  LDA candidateTop
  STA collisionPixelY
  JSR EvaluateCollisionPoint
  RTS
.endproc

; ------------------------------------------------------------
; EvaluatePlayerTopRightCollisionPoint
; ------------------------------------------------------------
; Purpose:
;   Tests the top-right corner of the candidate hitbox.
;
; Inputs:
;   candidateRight, candidateTop
;
; Outputs:
;   A and collisionResult are blocked/allowed.
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidateRight, candidateTop
;
; Memory written:
;   collisionPixelX, collisionPixelY, collisionResult,
;   map lookup scratch variables
;
; Assumptions:
;   BuildCandidatePlayerBounds has already run.
;
; Side effects:
;   None besides documented collision scratch writes.
; ------------------------------------------------------------
.proc EvaluatePlayerTopRightCollisionPoint
  LDA candidateRight
  STA collisionPixelX
  LDA candidateTop
  STA collisionPixelY
  JSR EvaluateCollisionPoint
  RTS
.endproc

; ------------------------------------------------------------
; EvaluatePlayerBottomLeftCollisionPoint
; ------------------------------------------------------------
; Purpose:
;   Tests the bottom-left corner of the candidate hitbox.
;
; Inputs:
;   candidateLeft, candidateBottom
;
; Outputs:
;   A and collisionResult are blocked/allowed.
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidateLeft, candidateBottom
;
; Memory written:
;   collisionPixelX, collisionPixelY, collisionResult,
;   map lookup scratch variables
;
; Assumptions:
;   BuildCandidatePlayerBounds has already run.
;
; Side effects:
;   None besides documented collision scratch writes.
; ------------------------------------------------------------
.proc EvaluatePlayerBottomLeftCollisionPoint
  LDA candidateLeft
  STA collisionPixelX
  LDA candidateBottom
  STA collisionPixelY
  JSR EvaluateCollisionPoint
  RTS
.endproc

; ------------------------------------------------------------
; EvaluatePlayerBottomRightCollisionPoint
; ------------------------------------------------------------
; Purpose:
;   Tests the bottom-right corner of the candidate hitbox.
;
; Inputs:
;   candidateRight, candidateBottom
;
; Outputs:
;   A and collisionResult are blocked/allowed.
;
; Registers used:
;   A, Y
;
; Registers modified:
;   A, Y
;
; Memory read:
;   candidateRight, candidateBottom
;
; Memory written:
;   collisionPixelX, collisionPixelY, collisionResult,
;   map lookup scratch variables
;
; Assumptions:
;   BuildCandidatePlayerBounds has already run.
;
; Side effects:
;   None besides documented collision scratch writes.
; ------------------------------------------------------------
.proc EvaluatePlayerBottomRightCollisionPoint
  LDA candidateRight
  STA collisionPixelX
  LDA candidateBottom
  STA collisionPixelY
  JSR EvaluateCollisionPoint
  RTS
.endproc
