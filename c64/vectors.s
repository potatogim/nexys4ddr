;
; File generated by cc65 v 2.16 - Git 1ea5889a
;
	.fopt		compiler,"cc65 v 2.16 - Git 1ea5889a"
	.setcpu		"6502"
	.smart		on
	.autoimport	on
	.case		on
	.debuginfo	off
	.importzp	sp, sreg, regsave, regbank
	.importzp	tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4
	.macpack	longbranch

; ---------------------------------------------------------------
; void __near__ __fastcall__ irq (void)
; ---------------------------------------------------------------

.segment	"VECTORS"

.addr _irq
.addr _irq
.addr _irq

