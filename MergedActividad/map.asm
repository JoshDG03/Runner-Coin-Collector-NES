; Metatile table copied from act 5/src/Step4_code.asm.
; TL, TR, BL, BR
metatile_table:
  .byte $06,$07,$16,$17
  .byte $0C,$0D,$1C,$1D
  .byte $04,$05,$14,$15
  .byte $0A,$0B,$1A,$1B

; Attribute table copied from act 5/src/screen.asm.
attrtable:
  .byte $C0,$C0,$C0,$C0,$C0,$C0,$E0,$30
  .byte $8C,$CF,$F8,$CA,$88,$C8,$C8,$32
  .byte $C8,$CA,$C8,$CA,$CA,$CC,$CC,$33
  .byte $88,$AE,$AC,$AF,$AC,$8F,$EC,$33
  .byte $CC,$FC,$CA,$CE,$CC,$88,$CC,$33
  .byte $CC,$CF,$8C,$CC,$AF,$EC,$CC,$33
  .byte $C8,$C8,$CA,$FA,$CA,$CE,$CC,$33
  .byte $00,$00,$00,$00,$00,$00,$00,$00
