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
BUTTON_START  = %00010000

.segment "ZEROPAGE"
controller1:         .res 1
previousController1: .res 1
pauseFlag:           .res 1

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
;     bit 4 = Start
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
;   Directional movement and Start pause are used right now. A/B and
;   Select are read by the same 8-bit sequence but are not used yet.
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

; ------------------------------------------------------------
; UpdatePauseToggle
; ------------------------------------------------------------
; Purpose:
;   Toggles pauseFlag only when Start changes from not pressed to
;   pressed. This prevents holding Start from rapidly toggling pause
;   every frame.
;
; Inputs:
;   controller1 = current controller state
;   previousController1 = previous frame's controller state
;
; Outputs:
;   pauseFlag toggles between $00 and $01 on a new Start press.
;   previousController1 becomes controller1.
;
; Registers used:
;   A
;
; Registers modified:
;   A
;
; Memory read:
;   controller1, previousController1, pauseFlag
;
; Memory written:
;   pauseFlag, previousController1
;
; Assumptions:
;   ReadController has already run this frame.
;
; Side effects:
;   None besides updating pause state.
; ------------------------------------------------------------
.proc UpdatePauseToggle
  LDA controller1
  AND #BUTTON_START
  BEQ store_previous_controller

  LDA previousController1
  AND #BUTTON_START
  BNE store_previous_controller

  LDA pauseFlag
  EOR #$01
  STA pauseFlag

store_previous_controller:
  LDA controller1
  STA previousController1
  RTS
.endproc
