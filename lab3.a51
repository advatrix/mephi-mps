org 8000h
P4 equ 0c0h
jmp start
org 8003h
jmp int

start:

; load test data
; A = [0, 55h, F0h, 7Fh]
; B = [0, B4h, 0, 0]
	mov DPTR, #8001h
	mov A, #55h
	movx @DPTR, A
	
	inc DPTR
	mov A, #0F0h
	movx @DPTR, A
	
	inc DPTR
	mov A, #0FDh
	movx @DPTR, A
	
	inc DPTR
	inc DPTR
	mov A, #0B4h
	movx @DPTR, A

	mov sp, #80h
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
	mov DPTR, #8004h
	anl A, #3; take 2 low bits
	add A, DPL
	mov DPL, A
	movx A, @DPTR
	mov R1, A; R1 <- B
	mov A, R0
	rr A
	rr A; A.0 - A.1 is idx A
	anl A, #3
	mov R3, A; R3 <- idx A
	mov DPTR, #8000h
	add A, DPL
	mov DPL, A
	movx A, @DPTR
	mov R2, A; R2 <- A
	mov 20h, A
; number of ones in A(R2) even bits (A.0 + A.2 + A.4 + A.6)
	mov R5, #4; 4 cycles of shifting and addition
	mov R6, #0; R6 - current sum of ones
	mov R4, A; R4 - current shifted A
	shift_cycle_A:
		mov A, R4
		rrc A
		rr A
		mov R4, A
		clr A
		addc A, R6
		mov R6, A
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
; number of zeros in bits whose numbers are more than index of A
; 1. shift B [idx A + 1] times
; 	if idx A = 0 then we count B.7 - B.1 => min 1 shift
; 2. calculate number of shifts of B as (7 - idx A)
; 3. shift B (7 - idx A) times and count zeros
; R7 - second sum
	mov R7, #0
	clr c
	mov A, R3
	push ACC; stack: (idx A)
	mov A, R3; acc <- idx A
	inc A
	mov R3, A; R3 := (idx A + 1)
; 1. shift B [idx A + 1] times
	shift_cycle_B:
		mov A, R1
		rr A
		mov R1, A
		djnz R3, shift_cycle_B
	pop ACC
	mov R3, A
	mov A, #7
	subb A, R3
	mov R3, A; R3 <- number of B shifts
	shift_cycle_B_count:
		mov A, R1
		cpl A; rotate complemented B to count zeros instead of ones
		rrc A
		cpl A
		mov R1, A; save rotated B
		clr A
		addc A, R7; update zeros count
		mov R7, A; save zeros count
		djnz R3, shift_cycle_B_count
compare:
	; R0 <- min(R6, R7)
	clr c; clear carry/borrow flag
	subb A, R6; A <- R7 - R6
	; if (R7 - R6) < 0 (the same as R7 < R6) then we'll have borrow
	jc load_r7
	mov A, R6
	mov R0, A
	jmp finish
load_r7:
	mov A, R7
	mov R0, A
	jmp finish
	
logic:
; shift left N times inputing 1
; N = (addr A mod 2) * (addr B)
; N in [0, 3]
	; load addr A and addr B to R1 and R2 respectively
	; calculate N and store it in R3
	; shift R0 R3 times
	
	rr A; A.0-A.1 is addr B
	push ACC
	anl A, #3; take 2 low bits and get addr B
	mov R2, A
	pop ACC
	rr A
	rr A
	anl A, #3; take 2 low bits and get addr A
	mov R1, A
	
	; load A
	mov DPTR, #8000h
	mov A, R1
	mov DPL, A
	movx A, @DPTR; load A
	mov R0, A
	
; calculate N
; addr A mod 2
	mov A, R1
	anl A, #1h; A = A mod 2
	mov B, A
; addr B
	mov A, R2
	mul AB
	
	jz finish
	
	mov R3, A; save num of shifts
	; load A
	mov A, R0
	
	setb c; for input 1
	
	logic_shift_cycle:
		rlc A
		setb c
		djnz R3, logic_shift_cycle
		
	mov R0, A
finish:
	jmp main
	; reti
	
end