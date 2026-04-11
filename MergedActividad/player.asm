.segment "ZEROPAGE"
player_x:     .res 1
player_y:     .res 1
tile_top:     .res 1
tile_bot:     .res 1
attributes:   .res 1
oam_ptr:      .res 1
anim_counter: .res 1
anim_frame:   .res 1
direction:    .res 1

.segment "CODE"

.proc init_player
  LDA #$40
  STA player_x
  LDA #$30
  STA player_y

  LDA #$00
  STA direction
  STA anim_counter
  STA anim_frame
  STA oam_ptr
  RTS
.endproc

.proc ppu_commit
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  RTS
.endproc

.proc clear_oam_buffer
  LDX #$00
  LDA #$FF
loop_clear:
  STA $0200, X
  INX
  INX
  INX
  INX
  BNE loop_clear
  RTS
.endproc

.proc update_animation
  LDA controller1
  AND #BUTTON_RIGHT
  BNE controller_pressed_right

  LDA controller1
  AND #BUTTON_DOWN
  BNE controller_pressed_down

  LDA controller1
  AND #BUTTON_LEFT
  BNE controller_pressed_left

  LDA controller1
  AND #BUTTON_UP
  BNE controller_pressed_up

  LDA #$00
  STA anim_counter
  STA anim_frame
  RTS

controller_pressed_right:
  LDA #$00
  STA direction
  JMP animate_controller_movement

controller_pressed_down:
  LDA #$01
  STA direction
  JMP animate_controller_movement

controller_pressed_left:
  LDA #$02
  STA direction
  JMP animate_controller_movement

controller_pressed_up:
  LDA #$03
  STA direction

animate_controller_movement:
  INC anim_counter
  LDA anim_counter
  CMP playerMoveSpeedTicks
  BNE done_update

  LDA #0
  STA anim_counter

  LDA anim_frame
  EOR #$01
  STA anim_frame

  JSR move_character

done_update:
  RTS
.endproc

; ------------------------------------------------------------
; move_character
; ------------------------------------------------------------
; CONTROLLER MOVEMENT + COLLISION HOOK
;
; update_animation sets direction from controller1 before calling
; this routine. This routine then builds a candidate position,
; asks the collision module if that candidate is blocked, and only
; commits the move if the candidate position is legal.
;
; Partner/controller merge notes:
;   If the controller logic changes later, keep this pattern:
;   copy player_x/player_y into candidatePlayerX/Y, modify the
;   candidate values, call IsPlayerCandidatePositionBlocked, and
;   commit only when collisionResult is $00.
; ------------------------------------------------------------
.proc move_character
  LDA player_x
  STA candidatePlayerX
  LDA player_y
  STA candidatePlayerY

  LDA direction
  CMP #0
  BEQ move_right
  CMP #1
  BEQ move_down
  CMP #2
  BEQ move_left
  JMP move_up

move_right:
  INC candidatePlayerX
  JMP try_commit_candidate

move_down:
  INC candidatePlayerY
  JMP try_commit_candidate

move_left:
  DEC candidatePlayerX
  JMP try_commit_candidate

move_up:
  DEC candidatePlayerY
  JMP try_commit_candidate

try_commit_candidate:
  JSR IsPlayerCandidatePositionBlocked
  LDA collisionResult
  BNE done

  LDA candidatePlayerX
  STA player_x
  LDA candidatePlayerY
  STA player_y

done:
  RTS
.endproc

.proc draw_character
  LDA #0
  STA oam_ptr

  LDA direction
  CMP #0
  BEQ draw_right
  CMP #1
  BEQ draw_down
  CMP #2
  BEQ draw_left
  JMP draw_up

draw_right:
  LDA #$03
  STA tile_top
  LDA anim_frame
  BEQ rightA
  LDA #$17
  JMP right_done
rightA:
  LDA #$07
right_done:
  STA tile_bot
  LDA #$00
  STA attributes
  JSR draw_posture
  RTS

draw_left:
  LDA #$03
  STA tile_top
  LDA anim_frame
  BEQ leftA
  LDA #$17
  JMP left_done
leftA:
  LDA #$07
left_done:
  STA tile_bot
  LDA #%01000000
  STA attributes
  JSR draw_posture
  RTS

draw_down:
  LDA #$01
  STA tile_top
  LDA anim_frame
  BEQ downA
  LDA #$09
  JMP down_done
downA:
  LDA #$11
down_done:
  STA tile_bot
  LDA #$00
  STA attributes
  JSR draw_posture
  RTS

draw_up:
  LDA #$05
  STA tile_top

  LDA anim_frame
  BEQ up_idle
  LDA #$09
  JMP up_done
up_idle:
  LDA #$15
up_done:
  STA tile_bot

  LDA #$00
  STA attributes
  JSR draw_posture
  RTS
.endproc

.proc draw_posture
  LDX oam_ptr

  LDA attributes
  AND #$C0
  CMP #$00
  BEQ case_none
  CMP #$40
  BEQ dispatch_h
  CMP #$80
  BEQ dispatch_v
  JMP case_hv

dispatch_h:
  JMP case_h
case_none:
  LDA player_y
  STA $0200, X
  LDA tile_top
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  STA $0200, X
  LDA tile_top
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_bot
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_bot
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X

  TXA
  CLC
  ADC #$04
  TAX
  STX oam_ptr
  RTS

dispatch_v:
  JMP case_v
case_h:
  LDA player_y
  STA $0200, X
  LDA tile_top
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  STA $0200, X
  LDA tile_top
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_bot
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_bot
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X

  TXA
  CLC
  ADC #$04
  TAX
  STX oam_ptr
  RTS

case_v:
  LDA player_y
  STA $0200, X
  LDA tile_bot
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  STA $0200, X
  LDA tile_bot
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_top
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_top
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X

  TXA
  CLC
  ADC #$04
  TAX
  STX oam_ptr
  RTS

case_hv:
  LDA player_y
  STA $0200, X
  LDA tile_bot
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  STA $0200, X
  LDA tile_bot
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  CLC
  ADC #$08
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_top
  CLC
  ADC #$01
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
  STA $0203, X
  TXA
  CLC
  ADC #$04
  TAX

  LDA player_y
  CLC
  ADC #$08
  STA $0200, X
  LDA tile_top
  STA $0201, X
  LDA attributes
  STA $0202, X
  LDA player_x
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
