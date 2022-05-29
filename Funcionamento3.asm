
; Funcionamento 3


.equ D0=0xC0
.equ D1=0xF9
.equ D2=0xA4
.equ D3=0xB0
.equ D4=0x99
.equ D5=0x92
.equ D6=0x82
.equ D7=0xF8
.equ D8=0x80
.equ D9=0x90

.def VAGAS=r18
.def VAGASMAX=r21
.def aux1=r23
.def aux2=r24
.def aux3=r25
.def ncarros=r20

.cseg
.org 0

jmp main
.cseg
.org 0x46	; saltar as posições de endereços dedicados às interrupções

table:
.db D0,D1,D2,D3,D4,D5,D6,D7,D8,D9



inicio:					; definir configurações de I/O a usar no programa
	ldi r16,0b11000000 		; todos ligados
	ldi r17,0b11111111 		; todos desligados

	out DDRA,r17 			; Definir como saida os LED's
	out PORTA,r17 			; Desligar todos os LED's

	out DDRD,r16 			; Definir como entrada os switches + set display
	out PORTD,r17 			; Desligar o display

	out DDRC,r17 			; Definir como saida o display
	out PORTC,r17 			; Desligar o display

	ldi ncarros,0

	ret	
	
	
main: 					; configurar o stack pointer
	ldi r22,low(ramend)
	out SPL,r22
	ldi r22,high(ramend)
	out SPH,r22
	
	call inicio



caso4:					; ( inicia o programa com o numero máximo de vagas igual a 4 (VAGASMAX==4))
	ldi VAGAS,4
	ldi VAGASMAX,4
	rjmp M2

caso:

	sbis PIND,5 			; caso se carregue no SW6 o limite é de 9 casos
	call SW6

	sbis PIND,4 			; caso se carregue no SW5 o limite é de 4 casos
	call SW5

	call display


	cpi VAGAS,1 			; if VAGAS < 1 ,0<= VAGAS <= 255 pertence aos números naturais
	brlo M1 				; (se VAGAS<1, ou seja, VAGAS==0 entra em M1)

	cp VAGAS,VAGASMAX 		; ( como o numero de vagas é maximo caso 2 só deixa decrementar VAGAS, ou seja, entrar um carro) 
	brsh caso2 			;if VAGAS >= VAGASMAX entra em caso 2

	sbis PIND,0 			;(se o SW1 estiver pressionado entra em SW1)
	call SW1

	sbis PIND,1
	call SW2

	cpi VAGAS,0
	brne M2 				;(se Vagas !=0 entra em M2)

	rjmp caso


decr:
	dec VAGAS 
	inc ncarros
	rjmp caso

incr:
	dec ncarros
	cp ncarros,VAGASMAX 		;(compara o numero de carros (ncarros) com as VAGASMAX, na transiçao de 9 vagas para 4 não se altera o valor de ncarros, pois caso estejam mais de 4 carros no parque temos de deixar sair os mesmos)
	
	brsh caso 			;(caso o numero de carros seja maior ou igual a VAGASMAX (ncarros>=VAGASMAX) entra em caso)
	inc VAGAS
	rjmp caso

caso1: 					; caso o numero de vagas seja minimo (parque cheio)
	sbis PIND,1
	call SW2
	rjmp caso

caso2: 					; caso o numero de vagas seja máximo (parque vazio)
	sbis PIND,0
	call SW1
	jmp caso

para94:
	subi VAGAS,5 			;(VAGAS=VAGAS-5)
	jmp caso
	
M1: 					; se tiver cheio
	ldi r19,0b01111111 		; acender o 8 led LED8
	out PORTA,r19
	jmp caso1
	
M2: 					; se ainda tiver espaço
	ldi r19,0b10111111 		; acender o 7 led LED7
	out PORTA,r19
	jmp caso


caso42:
	cpi VAGASMAX,4
	breq caso 			;(entra em caso se VAGASMAX==4)
	    
	ldi VAGASMAX,4
	cpi VAGAS,5
	brsh para94 			;(entra se VAGAS >=5, ou seja, menos de 4 carros ou 4 carros)
	ldi VAGAS,0  			;(para evitar vagas negativas se VAGAS<5 não entra em "para94" pois lá é subtraido 5 a VAGAS,mas não se altera o conteúdo de ncarros)

	jmp caso
	
caso9:
	 cpi VAGASMAX,9
	 breq caso 			;(se VAGASMAX já for 9 não é incrementado mais vagas)
	 
	 ldi VAGASMAX,9 
	 inc VAGAS
	 inc VAGAS
	 inc VAGAS
	 inc VAGAS
	 inc VAGAS 			;(incremento 5 vagas pois se antes a lotação era de 4 agora que é de 9 temos mais 5 lugares disponiveis)
	 
	 jmp caso



SW1:					;(avalia a transição do valor logico do sw1 (zero quando pressionado e 1 quando não pressinado)) PARA ENTRAR AQUI O SW1 TEM DE SER PRESSIONADO
	ldi aux1,0b11111110 		;(aux1 funciona como se o SW1 estivesse pressionado)
	call delay
	in aux2,PIND 			;(aux2 fica com o "conteúdo" do PIND)
	ori aux2,0b11111110
	cp aux1,aux2 			;(compara os aux ou seja compara se o SW1 ja deixou de ser pressionado)
	brne decr 			;(se aux1!=aux2 (o SW1 já não esta a ser pressionado) entra em decr )

	ret

SW2:
	ldi aux1,0b11111101
	call delay
	in aux2,PIND
	ori aux2,0b11111101
	cp aux1,aux2
	brne incr

	ret


SW5:
	ldi aux3,0b11101111
	call delay
	in aux2,PIND
	ori aux2,0b11101111 
	cp aux3,aux2			;(caso o Sw5 ja nao estiver pressionado troca o numero max de vagas)
	brne caso42 			;(caso42 serve para trocar o numero maximo de vagas (VAGASMAX) de 9 para 4)

	ret

SW6: 					;(avalia a transição do valor logico do sw6 (zero quando pressionado e 1 quando não pressinado))
	ldi aux3,0b11011111
	call delay
	in aux2,PIND
	ori aux2,0b11011111
	cp aux3,aux2
	brne caso9 			;(caso9 para trocar o numero maximo de vagas de 4 para 9 (VAGASMAX==9))

	ret

display:
	ldi ZL, low(table<<1)
	ldi ZH, high(table<<1)
	add ZL,VAGAS
	ldi r16,0
	adc ZH,r16
	lpm r10,Z
	out PORTC,r10
	ret

delay:
      push r18
      push r19
      push r20
     
      ldi r20,14
     
ciclo0:

      ldi r19,19
     
ciclo1:

      ldi r18,20
     
ciclo2:

      dec r18
      brne ciclo2

      dec r19
      brne ciclo1

      dec r20
      brne ciclo0

      pop r20
      pop r19
      pop r18
ret