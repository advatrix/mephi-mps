	; 2, 4, 5, 7, 9, 10, 11
; TT: 0010 1101 0111 0000 	
; F = x1 Nx0 Nx2 V X0(X2 xor X3) v Nx3 x2 Nx1
	
	P4 equ 0c0h; define P4 = 0c0h
	
; load truth table (ethalon)
; TODO: invert truth table

	mov A, #00101101b; 0 - 7
	cpl A
	mov DPTR, #8000h
	movx @DPTR, A
	
	mov A, #0111000b; 8 - 15
	cpl A
	mov DPTR, #8001h
	movx @DPTR, A
	
; indication
	clr P4.0
	setb P4.1
	
; counter prep
	clr A
	cpl A
	mov r1, A
	
counter:
	inc r1
	mov DPTR, #7FFAh
	mov A, r1
	movx @DPTR, A

continue:
	mov DPTR, #7FFbh
readiness_check:
	movx A, @DPTR; may be jnb A.0???
	anl A, #01h
	jz readiness_check
	
	; read key register state
	mov DPTR, #7FFAh
	movx A, @DPTR
	mov 20h, A; send A to bit memory
	
	; check if it's supported with A
	
	; calculate F
	mov c, 2
	; xrl c, 3; c = x2 xor x3, xrl may be not supported with C
	; xor can be implemented using sum A + B = (A xor B, A and B)
	; a xor b = (not ab) and (a or b)
	anl c, 3; c  = x2 * x3
	mov 4, c; [4] = x2 x3
	mov c, 2
	orl c, 3; c = x2 or x3
	anl c, /4; c = x2 xor x3
	anl c, 0; c = x0 (x2 xor x3)
	mov 4, c; or "mov 00, c" if A can be sdrressed bitwise
	
	mov c, 1; c = x1
	anl c, /0; c = x1 & nX0
	anl c, /2; c = x1 & nX0 & nX2
	orl c, 4
	mov 4, c
	
	mov c, 2
	anl c, /3
	anl c, /1
	
	orl c, 4
	mov P4.0, c
	
	; TODO: read from ethalon
	
	; reset readiness
	mov DPTR, #7FFBh
	mov A, #01h; TODO change to 00h
	movx @DPTR, A
	
	ajmp counter
	end
	