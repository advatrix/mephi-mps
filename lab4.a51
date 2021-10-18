; org 8000h
P4 equ 0c0h
IEN0 equ 0A8h
jmp start
org 13h; TODO set 8013h
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
	
	; запись кодов ССИ (по адресу 8008h)
	; 0
	inc DPTR; по адре
	mov A, #0F3h
	movx @DPTR, A
	
	; TODO заполнить таблицу кодов до F
	
	; запись кодов ЖКИ (по адресу 8008h + 10h = 8018h)
	; 0
	inc DPTR
	mov A, #30h; возможно надо менять местами полубайты
	movx @DPTR, A
	
	; 1
	inc DPTR
	mov A, #31h
	movx @DPTR, A

	mov sp, #80h
	setb EA; allow interrupts
	setb EX0; allow INT0
	clr IT0; 1/0
	
	mov IEN0, #84h ; allow INT1
	
	mov DPTR, #7FFFh
	mov A, #01h
	movx @DPTR, A; ввод символа слева, декодированный режим
	; установка режима дисплея ССИ
	
	; разрешение записи в видеопамять с автоинкрементированием
	; адреса
	
	mov DPTR, #7FFFh
	mov A, #90h
	; 90h = 100 10 000
	; запись в видеопамять, 8разр/8сим, кодир. сканирование
	movx @DPTR, A
	
	; настройка дисплея
	; две строки, размер символа 5 * 8
	mov A, #38h
	lcall dinit
	
	; включение дисплея
	mov A, #0Ch
	lcall dinit
	
	; включение сдвига курсора вправо
	mov A, #06h
	lcall dinit
	
	; сброс счетчика адреса и сдвига экрана
	mov A, #02h
	lcall dinit
	
	; очистка экрана
	mov A, #01h
	lcall dinit
	
main:
	mov A, R0
	swap A
	mov P4, A; в P4 little endian
	; mov P4, R0
	
	
	; запись в видеопамять
	; старшая тетрада в HEX формате в 3 знакоместо ССИ
	
	; весь байт R0 в 13 место 2 строки дисплея в HEX формате
	
	
	; команда записи в видеопамять в третье знакоместо
	mov A, #83h
	mov DPTR, #7FFFh
	movx @DPTR, A
	
	; получение кода символа для ССИ в зависимости от значения тетрады
	mov A, R0
	anl A, #0Fh
	add A, #08h
	mov DPH, #80h
	mov DPL, A
	movx A, @DPTR
	
	; отображение символа в ССИ (передача данных)
	mov DPTR, #7FFEh
	movx @DPTR, A
	
	; получение кода символа для ЖКИ
	; старшая тетрада
	mov A, R0
	anl A, #0F0h
	swap A
	add A, #18h
	mov DPH, #80h
	mov DPL, A
	movx A, @DPTR
	mov R1, A
	
	mov A, R0
	anl A, #0F0h
	add A, #18h
	mov DPL, A
	movx A, @DPTR
	mov R2, A
	
	; R1, R2 - коды (адреса) символов для индикации
	
	; установка счётчика на начальный адрес
	; mov A, #81h; это будет 1, но нужен другой (надо посчитать какой)
	; 13 знакоместо 2 строки => 28h + Dh = 35h = 53d
	; команда 
	; 1 0110101
	mov A, #10110101b
	lcall dinit
	
	; вывод первого символа
	mov A, R1
	lcall display
	
	mov A, #00011100b; сдвиг курсора вправо
	lcall dinit
	
	; вывод второго символа
	mov A, R2
	lcall display  
	
	sjmp main
	
int:
	; read input
	mov DPTR, #7ffAh
	movx A, @DPTR
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
	
	; проверка скан-кода клавиши '4'
	cjne A, #11001000b, arithmetic_check
	jmp logic

arithmetic_check:
	; проверка скан-кода клавиши '8'
	cjne A, #11010001b, finish_local
	jmp arithmetic
	
finish_local:
	ljmp finish
	
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
	reti
	
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

end