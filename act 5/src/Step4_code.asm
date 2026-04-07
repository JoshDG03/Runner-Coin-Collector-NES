; ============================================================
; activityv5v2 - compressed metatile background
; ============================================================

.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
row0:       .res 1
row1:       .res 1
row2:       .res 1
row3:       .res 1
mt_row:     .res 1          ; byte offset into compressed_screen: 0,4,8,...,56
row_index:  .res 1          ; metatile row number: 0..14
ppu_hi:     .res 1
ppu_lo:     .res 1
packed:     .res 1

.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  RTI
.endproc

.import reset_handler
.export main

.proc main
  ; ------------------------------------------------------------
  ; 1) Load palette to $3F00-$3F1F
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
@load_palettes:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$20
  BNE @load_palettes

  ; ------------------------------------------------------------
  ; 2) Clear nametable 0 ($2000-$23FF)
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #$00
  LDY #$00
@clear_nt:
  LDA #$00
  STA PPUDATA
  INX
  BNE @clear_nt
  INY
  CPY #$04
  BNE @clear_nt

  ; ------------------------------------------------------------
  ; 3) Decompress compressed_screen into nametable
  ;    15 metatile rows
  ;    each row = 4 packed bytes = 16 metatiles
  ; ------------------------------------------------------------
  LDA #$00
  STA mt_row
  STA row_index

@row_loop:
  ; ----------------------------------------
  ; Load this metatile row's 4 packed bytes
  ; ----------------------------------------
  LDY mt_row
  LDA compressed_screen, Y
  STA row0
  INY
  LDA compressed_screen, Y
  STA row1
  INY
  LDA compressed_screen, Y
  STA row2
  INY
  LDA compressed_screen, Y
  STA row3

  ; ----------------------------------------
  ; Lookup correct nametable address for this
  ; metatile row's TOP tile row
  ; ----------------------------------------
  LDY row_index
  LDA row_addr_hi, Y
  STA ppu_hi
  LDA row_addr_lo, Y
  STA ppu_lo

  ; ----------------------------------------
  ; Draw top half: TL TR
  ; ----------------------------------------
  LDA PPUSTATUS
  LDA ppu_hi
  STA PPUADDR
  LDA ppu_lo
  STA PPUADDR

  LDA row0
  STA packed
  JSR draw_top_from_packed

  LDA row1
  STA packed
  JSR draw_top_from_packed

  LDA row2
  STA packed
  JSR draw_top_from_packed

  LDA row3
  STA packed
  JSR draw_top_from_packed

  ; ----------------------------------------
  ; Draw bottom half: BL BR
  ; next tile row => +$20
  ; ----------------------------------------
  LDA PPUSTATUS
  LDA ppu_hi
  STA PPUADDR
  LDA ppu_lo
  CLC
  ADC #$20
  STA PPUADDR

  ; if low byte wrapped, increment high byte
  BCC :+
  INC PPUADDR
:
  LDA row0
  STA packed
  JSR draw_bottom_from_packed

  LDA row1
  STA packed
  JSR draw_bottom_from_packed

  LDA row2
  STA packed
  JSR draw_bottom_from_packed

  LDA row3
  STA packed
  JSR draw_bottom_from_packed

  ; ----------------------------------------
  ; Next metatile row
  ; ----------------------------------------
  LDA mt_row
  CLC
  ADC #$04
  STA mt_row

  INC row_index
  LDA row_index
  CMP #$0F
  BEQ @done_rows
  JMP @row_loop

@done_rows:

  ; ------------------------------------------------------------
  ; 4) Load attribute table (64 bytes) into $23C0-$23FF
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR

  LDX #$00
@attr64:
  LDA screen+$3C0, X
  STA PPUDATA
  INX
  CPX #$40
  BNE @attr64

  ; ------------------------------------------------------------
  ; 5) Wait for vblank and enable rendering
  ; ------------------------------------------------------------
@vblankwait:
  BIT PPUSTATUS
  BPL @vblankwait

  ; reset scroll to top-left
  LDA PPUSTATUS
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  LDA #%10000000
  STA PPUCTRL

  LDA #%00001010
  STA PPUMASK

@forever:
  JMP @forever
.endproc


; ------------------------------------------------------------
; packed byte contains 4 metatiles:
; bits 7-6, 5-4, 3-2, 1-0
; draw top row: TL TR
; ------------------------------------------------------------
.proc draw_top_from_packed
  ; metatile 0
  LDA packed
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  JSR draw_top_pair

  ; metatile 1
  LDA packed
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  JSR draw_top_pair

  ; metatile 2
  LDA packed
  LSR A
  LSR A
  AND #$03
  JSR draw_top_pair

  ; metatile 3
  LDA packed
  AND #$03
  JSR draw_top_pair

  RTS
.endproc


; ------------------------------------------------------------
; draw bottom row: BL BR
; ------------------------------------------------------------
.proc draw_bottom_from_packed
  ; metatile 0
  LDA packed
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  JSR draw_bottom_pair

  ; metatile 1
  LDA packed
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  JSR draw_bottom_pair

  ; metatile 2
  LDA packed
  LSR A
  LSR A
  AND #$03
  JSR draw_bottom_pair

  ; metatile 3
  LDA packed
  AND #$03
  JSR draw_bottom_pair

  RTS
.endproc


; ------------------------------------------------------------
; A = metatile id 0..3
; writes TL, TR
; ------------------------------------------------------------
.proc draw_top_pair
  ASL A
  ASL A
  TAX

  LDA metatiles, X
  STA PPUDATA
  LDA metatiles+1, X
  STA PPUDATA

  RTS
.endproc


; ------------------------------------------------------------
; A = metatile id 0..3
; writes BL, BR
; ------------------------------------------------------------
.proc draw_bottom_pair
  ASL A
  ASL A
  TAX

  LDA metatiles+2, X
  STA PPUDATA
  LDA metatiles+3, X
  STA PPUDATA

  RTS
.endproc


.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler


.segment "RODATA"

palettes:
  .incbin "bomberman.pal"

.include "compressed_screen.asm"
.include "screen.asm"

; metatile lookup table
; TL, TR, BL, BR
metatiles:
  .byte $06,$07,$16,$17
  .byte $0C,$0D,$1C,$1D
  .byte $04,$05,$14,$15
  .byte $0A,$0B,$1A,$1B

; top tile-row address for each of the 15 metatile rows
; rows start at:
; $2000, $2040, $2080, $20C0,
; $2100, $2140, $2180, $21C0,
; $2200, $2240, $2280, $22C0,
; $2300, $2340, $2380
row_addr_hi:
  .byte $20,$20,$20,$20,$21,$21,$21,$21,$22,$22,$22,$22,$23,$23,$23

row_addr_lo:
  .byte $00,$40,$80,$C0,$00,$40,$80,$C0,$00,$40,$80,$C0,$00,$40,$80


.segment "CHR"
.incbin "bomberman.chr"