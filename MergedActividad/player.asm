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
  LDA #$40
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
  INC anim_counter
  LDA anim_counter
  CMP #8
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

.proc move_character
  LDA direction
  CMP #0
  BEQ move_right
  CMP #1
  BEQ move_down
  CMP #2
  BEQ move_left
  JMP move_up

move_right:
  INC player_x
  LDA player_x
  CMP #$A0
  BNE done
  LDA #1
  STA direction
  RTS

move_down:
  INC player_y
  LDA player_y
  CMP #$A0
  BNE done
  LDA #2
  STA direction
  RTS

move_left:
  DEC player_x
  LDA player_x
  CMP #$40
  BNE done
  LDA #3
  STA direction
  RTS

move_up:
  DEC player_y
  LDA player_y
  CMP #$40
  BNE done
  LDA #0
  STA direction

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
