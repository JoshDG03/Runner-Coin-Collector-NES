; Metatile table copied from Actividad5 actividad5.asm.
; TL, TR, BL, BR
metatile_table:
  ; 0 = Stone
  .byte $07,$08,$07,$08

  ; 1 = Water
  .byte $05,$06,$05,$06

  ; 2 = Sand
  .byte $03,$04,$03,$04

  ; 3 = Grass
  .byte $01,$02,$01,$02

; Attribute table copied from Actividad5 actividad5.asm.
attrtable:
  .byte $BB,$AA,$AA,$AA,$11,$FF,$55,$AA
  .byte $7B,$5A,$5A,$5A,$11,$FF,$55,$AA
  .byte $33,$00,$00,$00,$00,$FF,$AA,$AA
  .byte $33,$00,$00,$00,$F0,$FF,$5A,$5A
  .byte $33,$00,$00,$00,$FF,$FF,$00,$00
  .byte $33,$00,$00,$00,$AA,$66,$00,$00
  .byte $F3,$F0,$F0,$F0,$FA,$76,$AA,$AA
  .byte $FF,$FF,$FF,$FF,$FF,$F7,$FA,$FA
