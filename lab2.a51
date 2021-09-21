	; 2, 4, 5, 7, 9, 10, 11
; TT: 0010 1101 0111 0000 	
; F = x1 Nx0 Nx2 V X0(X2 xor X3) v Nx3 x2 Nx1

; 2 sec: 1, 6
; 3 sec: 3
; 4 sec: 5, 10
; 5 sec: 2, 11
; MODE: T0
; T0 - 13 bit - 8192
; f_out = 11.059 MHz
; f = 11.059 M / 12 = 921583.333 ps; 
; cycles per sec: 11.059 M / 12 / 8192 = 112.49 cps 

; 0.5 sec: 112.49 / 2 = 56 cycles of T0 = 0x38
; 2 sec: 112.49 * 2 = 225 cycles = 0xE1
; 3 sec: 112.49 * 3 = 337 cycles = 0x151
; 4 sec: 112.49 * 4 = 450 cycles = 0x1C2
; 5 sec: 112.49 * 5 = 562 cycles = 0x232

 
	org 8000h
	P4 equ 0c0h; define P4 = 0c0h

; load time map
	mov A, #38h; 57 - base on 8002h
	mov DPTR, #8002h
	movx @DPTR, A
	
	mov A, #1; 0 -> 0.5 sec
	mov DPTR, #8003h
	movx @DPTR, A
	
	mov A, #4; 1 -> 2 sec
	mov DPTR, #8004h
	movx @DPTR, A
	
	mov A, #10; 2 -> 5 sec
	mov DPTR, #8005h
	movx @DPTR, A
	
	mov A, #6; 3 -> 3 sec
	mov DPTR, #8006h
	movx @DPTR, A
	
	mov A, #1; 4 -> 0.5 sec
	mov DPTR, #8007h
	movx @DPTR, A
	
	mov A, #8; 5 -> 4 sec
	mov DPTR, #8008h
	movx @DPTR, A
	
	mov A, #4; 6 -> 2 sec
	mov DPTR, #8009h
	movx @DPTR, A
	
	mov A, #1; 7 -> 0.5 sec
	mov DPTR, #800Ah
	movx @DPTR, A
	
	mov A, #1; 8 -> 0.5 sec
	mov DPTR, #800Bh
	movx @DPTR, A
	
	mov A, #1; 9 -> 0.5 sec
	mov DPTR, #800Ch
	movx @DPTR, A
	
	mov A, #8; 10 -> 4 sec
	mov DPTR, #800Dh
	movx @DPTR, A
	
	mov A, #10; 11 -> 5 sec
	mov DPTR, #800Eh
	movx @DPTR, A
	
	mov A, #1; 12 -> 0.5 sec
	mov DPTR, #800Fh
	movx @DPTR, A
	
	mov A, #1; 13 -> 0.5 sec
	mov DPTR, #8010h
	movx @DPTR, A
	
	mov A, #1; 14 -> 0.5 sec
	mov DPTR, #8011h
	movx @DPTR, A
	
	mov A, #1; 15 -> 0.5 sec
	mov DPTR, #8012h
	movx @DPTR, A
	
; load ethalon

	mov A, #10110100b; 0 - 7
	cpl A
	mov DPTR, #8000h
	movx @DPTR, A
	
	mov A, #00001110b; 8 - 15
	cpl A
	mov DPTR, #8001h
	movx @DPTR, A

; indication
	clr  P4.0
	setb P4.1
	
; counter prep
	mov A, #0xFF
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
	mov r2, A; save X for timer
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
	
	; timer
	mov TMOD, #00h; mode 0
	
	mov DPTR, #8002h; load base multiplier
	movx A, @DPTR; 
	mov B, A
	mov A, r2
	
	mov DPTR, #8003h; load base addr
	add A, DPL
	mov DPL, A
	movx A, @DPTR; A <- (DPTR + X)
	mul AB; BA = number of cycles
	; may be it's useless to move A and B to registers???
	
timer_cycle_outer:
	setb TR0; start timer
timer_start:
	setb TR0; start timer
	timer_check:
		jbc TF0, timer_finish; check if current cycle is done
		sjmp timer_check
	timer_finish:
		clr TR0; reset timer
		djnz A, timer_start; check if no cycles left
			
	; reset readiness
	mov DPTR, #7FFBh
	mov A, #01h; TODO change to 00h
	movx @DPTR, A
	
	ajmp counter; TODO change to continue
		
indicate_ethalon_zero:
	mov DPTR, #8000h 
	movx A, @DPTR
	ajmp indicate_ethalon
	
	end
	