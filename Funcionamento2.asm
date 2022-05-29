
; Funcionamento 2


.equ Xcount=210
.equ Ycount=136
.equ Zcount=140

start:
		ldi	r16, 0xff	; carrega registo r16 com 0b11111111
		out DDRC, r16		; definir leds (DDRC) como saídas
		out PORTC, r16
		ldi r16, 0x00		; limpar registo r16

					; PORTA (Botoes) nao esta definido porque por defeito são entradas
		ldi r16, low (RAMEND)	
		out spl, r16
		ldi r16, high (RAMEND)
		out sph, r16




teste_botao:
		sbic PINA, 0	; se bit 0 estiver a 0 (botão pressionado) ignora próxima linha
		jmp teste_botao
		
rotina:
		ldi r16, 0b11111100	; carrega sequência requerida de leds no registo
		out PORTC, r16		; envia sequência para o Port onde estão os leds
		call delay		; chama a rotina de delay ( 1 segundo )
		ldi r16, 0b11110011
		out PORTC, r16
		call delay
		ldi r16, 0b11001111
		out PORTC, r16
		call delay
		ldi r16, 0b00111111
		out PORTC, r16
		call delay

		sbic PINA, 0	;se bit 0 estiver a 0 (botão pressionado) executa rotina1
		jmp rotina	;se bit 0 estiver a 1 (botão  não pressionado) executa rotina
		jmp rotina1	

rotina1:
		ldi r16, 0b00111111	; carrega sequência requerida de leds no registo
		out PORTC, r16		; envia sequência para o Port onde estão os leds
		call delay		; chama a rotina de delay ( 1 segundo )
		ldi r16, 0b11001111
		out PORTC, r16
		call delay
		ldi r16, 0b11110011
		out PORTC, r16
		call delay
		ldi r16, 0b11111100
		out PORTC, r16
		call delay

		sbic PINA, 0	;se bit 0 estiver a 0 (botão pressionado) executa rotina
		jmp rotina1	;se bit 0 estiver a 1 (botão  não pressionado) executa rotina1
		jmp rotina


delay:
		push r16
		push r17
		push r18

		ldi  r18,Zcount		; carregar r18
ciclo3: 		ldi  r17,Ycount		; carregar r17
ciclo2:		ldi  r16,Xcount		; carregar r16
ciclo1:		dec r16			; decrementar r16
		cpi r16,0		; ver se r16 chegou a zero ( faz a operação r16 - 0 )
		brne ciclo1		; flag z = 1 se a operação anterior foi 0
					; se a flag z = 1 então segue em frente (resultados iguais)
					; se a flag z = 0 retrocede para ciclo1
					; testa a flag z, for 0 salta para ciclo1 se for 1 segue em frente)
		dec r17
		cpi r17,0
		brne ciclo2
		dec r18
		cpi r18,0
		brne ciclo3
		pop r18
		pop r17
		pop r16
		ret