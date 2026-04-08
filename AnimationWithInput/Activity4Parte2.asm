; ============================================================
; Activity 4 - Part 2 (Sprites) - FULL FILE (No flicker)
; - 16x16 (2x2) metasprite animates walking R/D/L/U
; - OAM built once per frame; NMI DMA only when ready
; - Uses a 4-tile table per frame (TL,TR,BL,BR)
; ============================================================

.include "constants.inc"
.include "header.inc"

; ---------------- Palette ----------------
SPR_PAL      = $03
ATTR_NORMAL  = SPR_PAL
ATTR_HFLIP   = $40 | SPR_PAL

; ---------------- Movement speed ----------------
SPEED_TICKS    = 1     ; bigger = slower

; ---------------- Controller buttons ----------------
JOYPAD1       = $4016
BUTTON_RIGHT  = %00000001
BUTTON_LEFT   = %00000010
BUTTON_DOWN   = %00000100
BUTTON_UP     = %00001000

; ---------------- Frame IDs ----------------
; We store tiles in frame_tiles in this order:
FRAME_DOWN_IDLE  = 0
FRAME_DOWN_A     = 1
FRAME_DOWN_B     = 2

FRAME_UP_IDLE    = 3
FRAME_UP_B       = 4

FRAME_RIGHT_IDLE = 5
FRAME_RIGHT_B    = 6

.segment "ZEROPAGE"
oam_index:   .res 1
nmi_tick:    .res 1
oam_ready:   .res 1
controller1: .res 1

current_direction: .res 1   ; 0=R,1=D,2=L,3=U
current_frame:     .res 1   ; 0=A,1=B   (we’ll interpret per-direction below)
frame_counter:     .res 1
pos_x:             .res 1
pos_y:             .res 1

tmp_frame: .res 1
tmp_x:     .res 1
tmp_y:     .res 1
tmp_attr:  .res 1
tmp_flip:  .res 1
tmp_tl:    .res 1
tmp_tr:    .res 1
tmp_bl:    .res 1
tmp_br:    .res 1

.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$01
  STA nmi_tick

  LDA oam_ready
  BEQ @skip

  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  LDA #$00
  STA oam_ready

@skip:
  RTI
.endproc

.import reset_handler
.export main

.proc main
  ; Load palettes
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
@pal:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$20
  BNE @pal

  ; init state
  LDA #$00
  STA current_direction
  STA current_frame
  STA frame_counter
  STA nmi_tick
  STA oam_ready
  STA controller1

  LDA #$60
  STA pos_x
  LDA #$60
  STA pos_y

@vblankwait:
  BIT PPUSTATUS
  BPL @vblankwait

  LDA #%10010000
  STA PPUCTRL

  LDA #%00010000
  STA PPUMASK

  LDA #$00
  STA $2005
  STA $2005

  ; build first frame
  JSR UpdateAnimation
  JSR DrawCharacter
  LDA #$01
  STA oam_ready

@loop:
@wait:
  LDA nmi_tick
  BEQ @wait
  LDA #$00
  STA nmi_tick

  JSR ReadController
  JSR UpdateAnimation
  JSR DrawCharacter
  LDA #$01
  STA oam_ready

  JMP @loop
.endproc


.proc ReadController
  LDA #$01
  STA JOYPAD1
  LDA #$00
  STA JOYPAD1
  STA controller1

  LDX #$08
@loop:
  LDA JOYPAD1
  LSR A
  ROL controller1
  DEX
  BNE @loop
  RTS
.endproc


.proc UpdateAnimation
  LDA controller1
  AND #BUTTON_RIGHT
  BNE @press_right

  LDA controller1
  AND #BUTTON_DOWN
  BNE @press_down

  LDA controller1
  AND #BUTTON_LEFT
  BNE @press_left

  LDA controller1
  AND #BUTTON_UP
  BNE @press_up

  LDA #$00
  STA frame_counter
  STA current_frame
  RTS

@press_right:
  LDA #$00
  STA current_direction
  JMP @animate

@press_down:
  LDA #$01
  STA current_direction
  JMP @animate

@press_left:
  LDA #$02
  STA current_direction
  JMP @animate

@press_up:
  LDA #$03
  STA current_direction

@animate:
  INC frame_counter
  LDA frame_counter
  CMP #SPEED_TICKS
  BNE @done

  LDA #$00
  STA frame_counter

  ; toggle A/B
  LDA current_frame
  EOR #$01
  STA current_frame

  ; move 1px
  LDA current_direction
  CMP #$00
  BEQ @right
  CMP #$01
  BEQ @down
  CMP #$02
  BEQ @left
@up:
  DEC pos_y
  JMP @done
@right:
  INC pos_x
  JMP @done
@down:
  INC pos_y
  JMP @done
@left:
  DEC pos_x

@done:
  RTS
.endproc


.proc DrawCharacter
  JSR ClearOAMBuffer
  LDA #$00
  STA oam_index

  LDA pos_x
  STA tmp_x
  LDA pos_y
  STA tmp_y

  LDA #ATTR_NORMAL
  STA tmp_attr
  LDA #$00
  STA tmp_flip

  ; choose frame id based on direction + toggle
  LDA current_direction
  CMP #$00
  BEQ @dir_right
  CMP #$01
  BEQ @dir_down
  CMP #$02
  BEQ @dir_left
  JMP @dir_up

@dir_right:
  ; Right uses: IDLE <-> B
  LDA current_frame
  BEQ @rIdle
    LDA #FRAME_RIGHT_B
    STA tmp_frame
    JMP @draw
@rIdle:
  LDA #FRAME_RIGHT_IDLE
  STA tmp_frame
  JMP @draw

@dir_left:
  ; Left mirrors Right
  LDA #ATTR_HFLIP
  STA tmp_attr
  LDA #$01
  STA tmp_flip

  LDA current_frame
  BEQ @lIdle
    LDA #FRAME_RIGHT_B
    STA tmp_frame
    JMP @draw
@lIdle:
  LDA #FRAME_RIGHT_IDLE
  STA tmp_frame
  JMP @draw

@dir_down:
  ; Down uses: A <-> B (you built two walk frames)
  LDA current_frame
  BEQ @dA
    LDA #FRAME_DOWN_B
    STA tmp_frame
    JMP @draw
@dA:
  LDA #FRAME_DOWN_A
  STA tmp_frame
  JMP @draw

@dir_up:
  ; Up uses: IDLE <-> B sway (feet hidden)
  LDA current_frame
  BEQ @uIdle
    LDA #FRAME_UP_B
    STA tmp_frame
    JMP @draw
@uIdle:
  LDA #FRAME_UP_IDLE
  STA tmp_frame

@draw:
  JSR DrawMetaSprite
  JSR HideUnusedSprites
  RTS
.endproc


; ---- Table-driven metasprite ----
.proc DrawMetaSprite
  ; X = tmp_frame * 4
  LDA tmp_frame
  ASL A
  ASL A
  TAX

  LDA frame_tiles, X
  STA tmp_tl
  INX
  LDA frame_tiles, X
  STA tmp_tr
  INX
  LDA frame_tiles, X
  STA tmp_bl
  INX
  LDA frame_tiles, X
  STA tmp_br

  LDA tmp_flip
  BEQ @ok

  ; swap for mirror layout
  LDA tmp_tl
  PHA
  LDA tmp_tr
  STA tmp_tl
  PLA
  STA tmp_tr

  LDA tmp_bl
  PHA
  LDA tmp_br
  STA tmp_bl
  PLA
  STA tmp_br

@ok:
  JSR PutSpriteTL
  JSR PutSpriteTR
  JSR PutSpriteBL
  JSR PutSpriteBR
  RTS
.endproc


.proc HideUnusedSprites
  LDY oam_index
  LDA #$F0
@loop:
  STA $0200,Y
  TYA
  CLC
  ADC #4
  TAY
  BNE @loop
  RTS
.endproc

.proc PutSpriteTL
  LDY oam_index
  LDA tmp_y
  STA $0200,Y
  INY
  LDA tmp_tl
  STA $0200,Y
  INY
  LDA tmp_attr
  STA $0200,Y
  INY
  LDA tmp_x
  STA $0200,Y
  INY
  STY oam_index
  RTS
.endproc

.proc PutSpriteTR
  LDY oam_index
  LDA tmp_y
  STA $0200,Y
  INY
  LDA tmp_tr
  STA $0200,Y
  INY
  LDA tmp_attr
  STA $0200,Y
  INY
  LDA tmp_x
  CLC
  ADC #8
  STA $0200,Y
  INY
  STY oam_index
  RTS
.endproc

.proc PutSpriteBL
  LDY oam_index
  LDA tmp_y
  CLC
  ADC #8
  STA $0200,Y
  INY
  LDA tmp_bl
  STA $0200,Y
  INY
  LDA tmp_attr
  STA $0200,Y
  INY
  LDA tmp_x
  STA $0200,Y
  INY
  STY oam_index
  RTS
.endproc

.proc PutSpriteBR
  LDY oam_index
  LDA tmp_y
  CLC
  ADC #8
  STA $0200,Y
  INY
  LDA tmp_br
  STA $0200,Y
  INY
  LDA tmp_attr
  STA $0200,Y
  INY
  LDA tmp_x
  CLC
  ADC #8
  STA $0200,Y
  INY
  STY oam_index
  RTS
.endproc

.proc ClearOAMBuffer
  LDX #$00
  LDA #$F0
@c:
  STA $0200,X
  INX
  BNE @c
  RTS
.endproc


.segment "RODATA"

; ============================================================
; FRAME TILE TABLE (TL,TR,BL,BR)
; Matches your real tile layout.
; If you moved your UP frames elsewhere, edit ONLY those two entries.
; ============================================================
frame_tiles:
  ; 0) DOWN_IDLE  ($04-$07)
  .byte $04, $05, $06, $07

  ; 1) DOWN_A      ($08-$0B)
  .byte $08, $09, $0A, $0B

  ; 2) DOWN_B      ($0C-$0F)
  .byte $0C, $0D, $0E, $0F

  ; 3) UP_IDLE     (ASSUMED $18-$1B)
  .byte $18, $19, $1A, $1B

  ; 4) UP_B        (ASSUMED $1C-$1F)
  .byte $1C, $1D, $1E, $1F

  ; 5) RIGHT_IDLE  ($10-$13)
  .byte $10, $11, $12, $13

  ; 6) RIGHT_B     ($14-$17)
  .byte $14, $15, $16, $17

palettes:
  .incbin "wizard.pal"

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "wizard.chr"
