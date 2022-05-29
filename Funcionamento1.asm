
; Funcionamento 1

					; PORTA (Botoes) nao esta definido porque por defeito são entradas
start:
		ldi r16, 0xff		
		out DDRC, r16		
		out PORTC, r16
		ldi r16, 0x00

bot0:
		sbic PINA, 0
		jmp bot1
		ldi r16, 0x00
		jmp ciclo

bot1:
		sbic PINA, 1
		jmp bot2
		ldi r16, 0b11100111 
		jmp ciclo

bot2:
		sbic PINA, 2
		jmp bot3
		ldi r16, 0b10011001
		jmp ciclo

bot3:
		sbic PINA, 3
		jmp bot4
		ldi r16, 0b01111110
		jmp ciclo

bot4:
		sbic PINA, 4
		jmp bot0
		ldi r16, 0b11111111
		jmp ciclo


ciclo:
		out PORTC, r16
    		inc r16
		jmp bot0
    


