	; 2, 4, 5, 7, 9, 10, 11
; TT: 0010 1101 0111 0000 	
; F = x1 Nx0 Nx2 V X0(X2 xor X3) v Nx3 x2 Nx1
	org 8000h
	P4 equ 0c0h; define P4 = 0c0h

; indication
	clr  P4.0
	setb P4.1

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
	
	; calculate F
	mov c, 2
	anl c, 3; c  = x2 * x3; x2 xor x3 = not(x2x3) and (x2 or x3)
	mov 4, c; [4] = x2 x3
	mov c, 2
	orl c, 3; c = x2 or x3
	anl c, /4; c = x2 xor x3
	anl c, 0; c = x0 (x2 xor x3)
	mov 4, c
	
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
	
	jz indicate_ethalon_zero
	
	anl A, #00000111b; clr A.3
	mov r0, A
	mov c, 3; check if > 7
	; ethalon_addr = 8000 + X3
	; shift [x2x1x0] times
	
	mov DPTR, #8000h
	mov A, #00h
	addc A, #0
	mov DPL, A
	; addc A, #0; A += X3, A = ethalon byte addr
	; movx DPTR, A
	movx A, @DPTR

shift_cycle:
	rr A
	djnz r0, shift_cycle
	
indicate_ethalon:
	mov 20h, A
	mov c, 0
	mov P4.1, c
	; reset readiness
	mov DPTR, #7FFBh
	mov A, #00h; TODO change to 00h
	movx @DPTR, A
	
	ajmp continue
		
indicate_ethalon_zero:
	mov DPTR, #8000h 
	movx A, @DPTR
	ajmp indicate_ethalon
	
	end
	