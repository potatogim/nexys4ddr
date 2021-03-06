.setcpu "6502"

.export nmi_int, irq_int   ; Used by lib/vectors.s
.export _isr_jump_table    ; Used by lib/sys_irq.c
.import timer_isr          ; See lib/timer_isr.s

; These must be the same addresses defined in prog/memorymap.h
IRQ_STATUS = $7FFF
IRQ_MASK   = $7FDF

.segment "BSS"
tmp1:
   .byte 0
tmp2:
   .byte 0
tmp3:
   .byte 0, 0

.segment "ZEROPAGE"

isr_ptr:
   .byte 0, 0              ; This is temporary scratch space.

.segment "DATA"

_isr_jump_table:
   .addr timer_isr         ; IRQ 0  (TIMER)
   .addr unhandled_irq     ; IRQ 1  (VGA)
   .addr unhandled_irq     ; IRQ 2  (Reserved)
   .addr unhandled_irq     ; IRQ 3  (Reserved)
   .addr unhandled_irq     ; IRQ 4  (Reserved)
   .addr unhandled_irq     ; IRQ 5  (Reserved)
   .addr unhandled_irq     ; IRQ 6  (Reserved)
   .addr unhandled_irq     ; IRQ 7  (Reserved)

.segment	"CODE"

; Unhandled interrupts just return immediately.
unhandled_irq:
   RTS

nmi_int:
   RTI                     ; NMI is not implemented. Just return.

irq_int:
   PHA
   TXA
   PHA
   TYA
   PHA

   LDA IRQ_STATUS          ; Reading the IRQ status clears it.
   AND IRQ_MASK            ; Mask off any disabled interrupts.
   LDY #$00                ; Start from bit 0
loop:
   LSR                     ; Shift current bit to carry
   BCC next_irq            ; Jump if current bit is clear

   LDX _isr_jump_table,Y   ; Load interrupt vector from table
   STX isr_ptr             ; and store in temporary pointer
   LDX _isr_jump_table+1,Y
   STX isr_ptr+1

   JSR jmp_isr_ptr         ; Jump indirectly to interrupt service routine, see below.
                           ; The A and Y registers MUST be preserved.

next_irq:
   TAX                     ; Optimization: If no more interrupts, quickly skip to the end.
   BEQ end
   INY
   INY
   CPY #$10                ; More interrupts?
   BNE loop                ; Jump back if so.

end:
   PLA
   TAY
   PLA
   TAX
   PLA
   RTI

jmp_isr_ptr:
   JMP (isr_ptr)
   
