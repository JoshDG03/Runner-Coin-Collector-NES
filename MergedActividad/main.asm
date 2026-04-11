; ============================================================
; MergedActividad - Actividad5 compressed map + Activity4 player
; ============================================================

.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
packed_index:  .res 1
meta_row:      .res 1
meta_col:      .res 1
cur_byte:      .res 1
temp:          .res 1
nt_lo:         .res 1
nt_hi:         .res 1
row_lo:        .res 1
row_hi:        .res 1
vblank_ready:  .res 1

.include "controller.asm"
.include "player.asm"
.include "collision.asm"
.include "enemy.asm"
.include "coin.asm"

.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  JSR ppu_commit

  ; Keep scroll latched to the top-left each frame while rendering.
  LDA PPUSTATUS
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  LDA #$01
  STA vblank_ready
  RTI
.endproc

.import reset_handler
.export main

.proc main
  LDA #$00
  STA PPUCTRL
  STA PPUMASK
  STA vblank_ready
  STA controller1
  STA previousController1
  STA pauseFlag

  JSR init_player
  JSR InitializeEnemy
  JSR InitCoinSystem

  ; ------------------------------------------------
  ; Load palettes
  ; ------------------------------------------------
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
load_pal:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_pal

  ; ------------------------------------------------
  ; Decompress packed map into NAMETABLE
  ; ------------------------------------------------
  LDA #$00
  STA packed_index
  STA meta_row
  STA row_lo

  LDA #$20
  STA row_hi

row_loop:
  LDA #$00
  STA meta_col

col_group_loop:
  LDY packed_index
  LDA packed_map, Y
  STA cur_byte
  INC packed_index

  LDA cur_byte
  LSR
  LSR
  LSR
  LSR
  LSR
  LSR
  AND #$03
  JSR draw_current_metatile
  INC meta_col

  LDA cur_byte
  LSR
  LSR
  LSR
  LSR
  AND #$03
  JSR draw_current_metatile
  INC meta_col

  LDA cur_byte
  LSR
  LSR
  AND #$03
  JSR draw_current_metatile
  INC meta_col

  LDA cur_byte
  AND #$03
  JSR draw_current_metatile
  INC meta_col

  LDA meta_col
  CMP #$10
  BNE col_group_loop

  LDA row_lo
  CLC
  ADC #$40
  STA row_lo
  BCC no_row_carry
  INC row_hi
no_row_carry:

  INC meta_row
  LDA meta_row
  CMP #$0F
  BNE row_loop

  ; ------------------------------------------------
  ; Write ATTRIBUTE TABLE ($23C0)
  ; ------------------------------------------------
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR

  LDX #$00
attr_loop:
  LDA attrtable, X
  STA PPUDATA
  INX
  CPX #$40
  BNE attr_loop

  JSR clear_oam_buffer
  JSR draw_character
  JSR DrawEnemySprites
  JSR DrawCoinSprite

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

  LDA PPUSTATUS
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  ; Enable NMI, use background pattern table 0 and sprite pattern table 1.
  LDA #%10001000
  STA PPUCTRL

  LDA #%00011110
  STA PPUMASK

main_loop:
wait_vblank:
  LDA vblank_ready
  BEQ wait_vblank

  LDA #$00
  STA vblank_ready

  JSR ReadController
  JSR UpdatePauseToggle
  LDA pauseFlag
  BNE skip_game_updates

  JSR update_animation
  JSR CheckCoinCollected
  JSR UpdateEnemy

skip_game_updates:
  JSR clear_oam_buffer
  JSR draw_character
  JSR DrawEnemySprites
  JSR DrawCoinSprite

  JMP main_loop
.endproc

.proc draw_current_metatile
  STA temp

  LDA meta_col
  ASL
  CLC
  ADC row_lo
  STA nt_lo

  LDA row_hi
  ADC #$00
  STA nt_hi

  LDA temp
  ASL
  ASL
  TAX

  LDA PPUSTATUS
  LDA nt_hi
  STA PPUADDR
  LDA nt_lo
  STA PPUADDR

  LDA metatile_table, X
  STA PPUDATA
  INX
  LDA metatile_table, X
  STA PPUDATA
  INX

  LDA nt_lo
  CLC
  ADC #$20
  STA nt_lo

  LDA nt_hi
  ADC #$00
  STA nt_hi

  LDA PPUSTATUS
  LDA nt_hi
  STA PPUADDR
  LDA nt_lo
  STA PPUADDR

  LDA metatile_table, X
  STA PPUDATA
  INX
  LDA metatile_table, X
  STA PPUDATA

  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"

palettes:
  .incbin "palettes.pal", 0, $20

.include "compressed_map.asm"
.include "map.asm"

.segment "CHR"
.incbin "tileset.chr"
.incbin "sprites.chr"
