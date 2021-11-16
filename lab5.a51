/*
Вариант 132 
Переключения: 4 5 6 2

N1 = 3
N2 = ((3 * N1 + 1) mod 3) == 1
N3 = 3 - 2 * N1
N4 = N1 + N2
*/
	
BUF_ADDR equ 24h
	

; начальное состояние
mov P1, #01h; состояние
mov P2, #00h; принятие

mov R1, #00h; N1
mov R2, #00h; N2
mov R3, #00h; N3
mov R4, #00h; N4
mov R7, #03h; допустимое количество ошибок в текущем состоянии

mov BUF_ADDR, P0; очистка буфера
; либо изначально в буфер класть стартовое значение P0


; цикл считывания входных данных
read_cycle:
	mov A, P0
	xrl A, BUF_ADDR
	cjne A, #00h, process_changes
	ajmp read_cycle
	
; обработать изменения во входных данных
process_changes:
	mov BUF_ADDR, P0; обновить буфер
	mov R0, A
	mov A, P1
		cjne A, #01h, check_state_2
		jmp state_1
	check_state_2:
		cjne A, #02h, check_state_3
		jmp state_2
	check_state_3:
		cjne A, #03h, check_state_4
		jmp state_3
	check_state_4:
		cjne A, #04h, failure
		jmp state_4


; в состоянии 1 ожидается переключение линии 4
state_1:
	mov A, R0
	jb ACC.4, transition_1_2
	inc R1; найдена ошибка 
	mov A, R7
	clr c
	subb A, R1
	jc failure
	jmp read_cycle

; переход из состояния 1 в состояние 2
transition_1_2:
	mov P1, #02h
	mov R7, #01h
	jmp read_cycle

; в состоянии 2 ожидается переключение линии 5
state_2:
	mov A, R0
	jb ACC.5, transition_2_3
	; не более 1 ошибки
	inc R2
	clr c
	mov A, R7
	subb A, R2
	jc failure
	jmp read_cycle
	
transition_2_3:
	mov P1, #03h
	mov A, R1
	clr C
	rl A; A := 2 * N1
	mov R0, A
	mov A, #3h
	subb A, R0; 
	jnc t23_load; A := max(0, 3 - 2 * N1)
		clr A
	t23_load:
		mov R7, A
	jmp read_cycle
	
state_3:
	mov A, R0
	jb ACC.6, transition_3_4
	inc R3
	clr C
	mov A, R7
	subb A, R3
	jc failure
	jmp read_cycle
	
transition_3_4:
	mov P1, #4h
	mov A, R1
	add A, R2
	mov R7, A
	jmp read_cycle
	
state_4:
	mov A, R0
	jb ACC.2, success
	inc R4
	mov A, R7
	clr C
	subb A, R4
	jc failure
	jmp read_cycle
	
failure:
	mov P1, #0AAh
	sjmp $

success:
	mov P1, #55h
	mov P2, #132d
	sjmp $
end