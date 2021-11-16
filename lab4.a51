org 8000h
P4 			equ 0c0h
IEN0 		equ 0A8h
ssi_cmd 	equ 7FFFh
ssi_data 	equ 7FFEh
led_cmd_w 	equ 7FF4h
led_data_w 	equ 7FF5h
led_cmd_r 	equ 7FF6h
led_data_r 	equ 7FF7h	
	
jmp start
org 8013h; TODO set 8013h
jmp int




start:
	; lcall load_memory ; загрузка данных в память (удалить)
	; mov sp, #80h 
	; setb EA; allow interrupts
	; setb EX0; allow INT0
	; clr IT0; 1/0
	mov IEN0, #84h ; allow INT1
	
	lcall init_ssi
	lcall init_led
	
main:
	mov A, R0
	swap A
	mov P4, A
	
	sjmp main
	
int:
	; read input
	mov DPTR, #7ffAh
	movx A, @DPTR
	mov R1, A
	; read opcode from keyboard
	; arithmetic - key '8'
	; logic - key '4'
	
	; чтение кода операции с клавиатуры
	; арифметическая операция - клавиша '8'
	; логическая - '4'
	
	; разрешение чтения FIFO клавиатуры
	mov DPTR, #7FFFh
	mov A, #40h
	movx @DPTR, A
	
	; чтение скан-кода
	mov DPTR, #7FFEh
	movx A, @DPTR
	
	; проверка скан-кода клавиши '4' (C8h)
	cjne A, #11001000b, arithmetic_check
	jmp logic

arithmetic_check:
	; проверка скан-кода клавиши '8' (D1h)
	cjne A, #11010001b, finish_local
	jmp arithmetic
	
finish_local:
	ljmp finish
	
arithmetic:
	; read addr B
	mov A, R1
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
	mov A, R1
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
	lcall display_ssi
	lcall display_led

	reti
	
init_led:
; настройка дисплея
	; две строки, размер символа 5 * 8
	mov A, #38h
	lcall dinit
	
	; включение дисплея
	mov A, #0Ch
	lcall dinit
	
	; включение сдвига курсора вправо
	;mov A, #06h
	;lcall dinit
	
	; сброс счетчика адреса и сдвига экрана
	mov A, #02h
	lcall dinit
	
	; очистка экрана
	mov A, #01h
	lcall dinit
	ret
	
init_ssi:
	mov DPTR, #ssi_cmd
	mov A, #01h; ввод символа слева
	movx @DPTR, A
	
	mov DPTR, #ssi_cmd
	mov A, #90h; запись с автоинкрементом адреса
	movx @DPTR, A
	
	mov DPTR, #ssi_data
	mov A, #00h; сброс всех ячеек видеопамяти
	movx @DPTR, A	
	movx @DPTR, A	
	movx @DPTR, A	
	movx @DPTR, A
	
	ret
	
display_ssi:
; процедура вывода старшей тетрады R0 в ССИ
	
	; запись в третье знакоместо
	mov DPTR, #ssi_cmd
	mov A, #82h
	movx @DPTR, A
		
	; получить данные
	mov A, R0
	swap A
	anl A, #0Fh
	add A, #08h
	mov DPH, #80h
	mov DPL, A
	movx A, @DPTR
	
	; запись в видеопамять
	mov DPTR, #ssi_data
	movx @DPTR, A
	
	ret
	
display_led:
; процедура вывода данных на дисплей
; данные - в R0
; вывод во вторую строку, 13 и 14 знакоместа
; адрес начала ввода - 34h
	
	; получение кодов символов
	; старшая тетрада
	
	mov A, R0
	swap A
	anl A, #0Fh
	add A, #18h
	mov DPH, #80h
	mov DPL, A
	movx A, @DPTR
	mov R1, A
	
	; младшая тетрада
	mov A, R0
	anl A, #0Fh
	add A, #18h
	mov DPH, #80h
	mov DPL, A
	movx A, @DPTR
	mov R2, A
	
	; команда 1 - установка счетчика
	;		   0110100 = 34h = 52d
	mov A, #10110100b
	lcall dinit
	
	mov A, R1
	lcall display
	
	;mov A, #00011100b
	mov A, #10110101b
	lcall dinit
	
	mov A, R2
	lcall display
	ret
	
dinit:
; процедура записи команды в управляющий регистр дисплея
	mov R3, A
	mov DPTR, #7FF6h
	
	dinit_wait:
		movx A, @DPTR
		anl A, #80h
		jnz dinit_wait
		
	mov DPTR, #7FF4h
	mov A, R3
	movx @DPTR, A
	ret
	
display:
; процедура вывода символа на ЖКИ
	mov R3, A
	mov DPTR, #7FF6h
	
	display_wait:
		movx A, @DPTR
		anl A, #80h
		jnz display_wait
	
	mov DPTR, #7FF5h
	mov A, R3
	movx @DPTR, A
	ret
	
load_memory:
; процедура загрузки тестовых данных в память
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
	
	inc DPTR
	inc DPTR
	
	; загрузка кодов ССИ
	; базовый адрес кодов ССИ: 8008h
	; код 0
	inc DPTR
	mov A, #0F3h
	movx @DPTR, A
	
	inc DPTR
	mov A, #60h; 1
	movx @DPTR, A
	
	inc DPTR
	mov A, #0B5h; 2
	movx @DPTR, A
	
	inc DPTR
	mov A, #0F4h; 3
	movx @DPTR, A
	
	inc DPTR
	mov A, #66; 4
	movx @DPTR, A
	
	inc DPTR
	mov A, #0D6h; 5
	movx @DPTR, A
	
	inc DPTR
	mov A, #0D7h; 6
	movx @DPTR, A
	
	inc DPTR
	mov A, #70h; 7
	movx @DPTR, A
	
	inc DPTR
	mov A, #0F7h; 8
	movx @DPTR, A
	
	inc DPTR
	mov A, #0F6h; 9
	movx @DPTR, A
	
	inc DPTR
	mov A, #77h; A
	movx @DPTR, A
	
	inc DPTR
	mov A, #0C7h; B
	movx @DPTR, A
	
	inc DPTR
	mov A, #93h; C
	movx @DPTR, A
	
	inc DPTR
	mov A, #0E5h; D
	movx @DPTR, A
	
	inc DPTR
	mov A, #97h; E
	movx @DPTR, A
	
	inc DPTR
	mov A, #17h; F
	movx @DPTR, A
	
	; загрузка кодов ЖКИ
	; базовый адрес ЖКИ: 8008h + 10h = 8018h
	
	inc DPTR
	mov A, #30h; 0
	movx @DPTR, A
	
	inc DPTR
	mov A, #31h; 1
	movx @DPTR, A
	
	inc DPTR
	mov A, #32h; 2
	movx @DPTR, A
	
	inc DPTR
	mov A, #33h; 3
	movx @DPTR, A
	
	inc DPTR
	mov A, #34h; 4
	movx @DPTR, A
	
	inc DPTR
	mov A, #35h; 5
	movx @DPTR, A
	
	inc DPTR
	mov A, #36h; 6
	movx @DPTR, A
	
	inc DPTR
	mov A, #37h; 7
	movx @DPTR, A
	
	inc DPTR
	mov A, #38h; 8
	movx @DPTR, A
	
	inc DPTR
	mov A, #39h; 9
	movx @DPTR, A
	
	inc DPTR
	mov A, #41h; A
	movx @DPTR, A
	
	inc DPTR
	mov A, #42h; B
	movx @DPTR, A
	
	inc DPTR
	mov A, #43h; C
	movx @DPTR, A
	
	inc DPTR
	mov A, #44h; D
	movx @DPTR, A
	
	inc DPTR
	mov A, #45h; E
	movx @DPTR, A
	
	inc DPTR
	mov A, #46h; F
	movx @DPTR, A
	
	inc DPTR
	mov A, #47h; F
	movx @DPTR, A
	
	ret

end