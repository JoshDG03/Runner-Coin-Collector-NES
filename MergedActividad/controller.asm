; ============================================================
; Controller input module
; ============================================================
;
; This module is intentionally small: it only reads controller 1
; and stores the current buttons in controller1. Player movement
; decides how to use those buttons.

JOYPAD1       = $4016
BUTTON_RIGHT  = %00000001
BUTTON_LEFT   = %00000010
BUTTON_DOWN   = %00000100
BUTTON_UP     = %00001000

.segment "ZEROPAGE"
controller1: .res 1

.segment "CODE"

; ------------------------------------------------------------
; ReadController
; ------------------------------------------------------------
; Purpose:
;   Reads NES controller 1 from $4016 and stores the directional
;   button state in controller1.
;
; Inputs:
;   Hardware controller port $4016.
;
; Outputs:
;   controller1 contains button bits:
;     bit 0 = Right
;     bit 1 = Left
;     bit 2 = Down
;     bit 3 = Up
;
; Registers used:
;   A, X
;
; Registers modified:
;   A, X
;
; Memory read:
;   JOYPAD1 / $4016
;
; Memory written:
;   controller1
;
; Assumptions:
;   Only directional movement is needed right now. A/B/Start/Select
;   are read by the same 8-bit sequence but are not used yet.
;
; Side effects:
;   Strobes controller port $4016.
; ------------------------------------------------------------
.proc ReadController
  LDA #$01
  STA JOYPAD1
  LDA #$00
  STA JOYPAD1
  STA controller1

  LDX #$08
read_controller_loop:
  LDA JOYPAD1
  LSR A
  ROL controller1
  DEX
  BNE read_controller_loop

  RTS
.endproc
