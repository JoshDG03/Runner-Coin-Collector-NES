.include "constants.inc"

.segment "CODE"
.import main
.export reset_handler

.proc reset_handler
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX PPUCTRL
  STX PPUMASK
  STX $4010
  BIT PPUSTATUS

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

  LDX #$00
  LDA #$FF
clear_oam:
  STA $0200, X
  INX
  INX
  INX
  INX
  BNE clear_oam

vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2
  JMP main
.endproc
