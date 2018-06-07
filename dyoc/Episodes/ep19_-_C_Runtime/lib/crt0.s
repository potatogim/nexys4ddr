	.setcpu		"6502"

   .export nmi_int, init, irq_int
   .export _exit
   .import _main

   .export __STARTUP__ : absolute = 1     ; Mark as startup
   .import __RAM_START__, __RAM_SIZE__    ; Linker generated

   .import copydata, zerobss, initlib, donelib

   .include "zeropage.inc"

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment	"STARTUP"

init:
   SEI         ; Disable interrupts
   CLD         ; Clear decimal mode
   LDX #$FF    ; Reset stack pointer
   TXS

; ---------------------------------------------------------------------------
; Set cc65 argument stack pointer

   LDA #<(__RAM_START__ + __RAM_SIZE__)
   STA sp
   LDA #>(__RAM_START__ + __RAM_SIZE__)
   STA sp+1   

; ---------------------------------------------------------------------------
; Initialize memory storage

   JSR zerobss              ; Clear BSS segment
   JSR copydata             ; Initialize DATA segment
   JSR initlib              ; Run constructors

; ---------------------------------------------------------------------------
; Call main()

   JSR _main

; ---------------------------------------------------------------------------
; Back from main (this is also the _exit entry):  force a software break

_exit:
   SEI                      ; Disable interrupts
   JSR donelib              ; Run destructors
halt:
   JMP halt

.segment	"CODE"

nmi_int:
   RTI

irq_int:
   RTI

