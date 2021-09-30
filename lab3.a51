org 8000h
P4 equ 0c0h
jmp start
org 8003h
jmp int

start:
	setb EA; allow interrupts
	setb EX0; allow INT0
	clr IT0; 1/0
main:
	mov P4, R0
	sjmp main
	
int:
	; read input
	mov DPTR, #7ffAh
	movx A, @DPTR
	jb acc.0, logic
arithmetic:
	; read addr B
	rr A; A.0-A.1 is idx B
	mov R0, A; R0 - work reg
	anl A, #3; take 2 low bits
	add A, 8004h; A <- addr B
	mov DPTR, A
	movx A, @DPTR
	mov R1, A; R1 <- B
	mov A, R0
	rr A
	rr A; A.0 - A.1 is idx A
	mov R3, A; R3 <- idx A
	anl A, #3
	add A, 8003h
	mov DPTR, A
	movx A, @DPTR
	mov R2, A; R2 <- A
	mov 20h, A
; number of ones in A(R2) even bits (A.0 + A.2 + A.4 + A.6)
	mov R5, #4; 4 cycles of shifting and addition
	mov R6, #0; R6 - current sum of ones
	mov R4, R2; R4 - current shifted A
	shift_cycle_A:
		mov A, R4
		rrc A
		mov R4, A
		clr A
		addc A, R2
		mov R2, A
		djnz R5, shift_cycle_A
; number of ones in (B.2 + B.4 + B.5 + B.7)
	mov 20h, R1
	clr A
	mov c, 2
	addc A, R6
	mov R6, A
	clr A
	mov c, 4
	addc A, R6
	mov R6, A
	clr A
	mov c, 5
	addc A, R6
	mov R6, A
	clr A
	mov c, 7
	addc A, R6
	mov R6, A
	clr A
; R6 - first sum
; number of zeros in bits whose numbers are less than index of A
; so we assume index of A is number of right shifts of B we do
; R7 - second sum
	mov R7, #0
	clr c
	mov A, R3
	cpl A; count zeros instead of ones
	jz compare
	shift_cycle_B:
		mov A, R1
		rrc A
		mov R1, A
		addc A, R7
		mov R7, A
		djnz R3, shift_cycle_B
compare:
	; R0 <- min(R6, R7)
	clr c; clear carry/borrow flag
	subb A, R6; A <- R7 - R6
	; if (R7 - R6) < 0 (the same as R7 < R6) then we'll have borrow
	jc 
	
logic:
	
	reti
	
end