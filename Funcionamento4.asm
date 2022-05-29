
; Funcionamento 4


.include<m128def.inc>

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
.equ E=0x86
.equ C=0xC6

.def temp=r16
.def seg=r17
.def cnt1=r18
.def cnt2=r19
.def temp_int=r20

.cseg
.org 0x0000
jmp main

.org 0x001E 					; endereço compare
jmp int_TIMER0

.cseg
.org 0x46					; saltar as posições de endereços dedicados às interrupções


table:
.db D0,D1,D2,D3,D4,D5,D6,D7,D8,D9



inicio:
	ldi temp,0b11000000 			; escolher o display de 7 segmentos mais a direita para funcionar

	out DDRD,temp 				; Definir como entrada os switches + set display
	out PORTD,temp 

	ldi temp,0b11111111 			; todos desligados

	out DDRC,temp 				; Definir como saida o display
	out PORTC,temp 				; Desligar o display


	ldi temp,124				; Definir o OCR0 (como 124), face ao calculo de 2ms=Prescaler(OCR0+1)/CLK10 e como o CLK10 é 16MHz e o OCR0 só pode ser entre 0 e 255 e tem de ser inteiro e o prescaler só pode tomar valores entre 128,256,1024 então pelos calculos da 124

	out OCR0,temp

	ldi temp,0 
	out TCNT0,temp 				; serve para o contador começar em 0

						; Definição de dois contadores de forma cnt1*cnt2*2ms=1 desta forma escolhemos cnt1=50 e cnt2=10
	ldi cnt1,50
	ldi cnt2,10

	ldi temp,0b00001110			; Definir o prescaler como 256
	out TCCR0,temp


	sei					; enable as interrupções  I=1
	ret

main: 						; configurar o stack pointer na posição da memoria de dados r22

	ldi r22,low(ramend)
	out SPL,r22
	ldi r22,high(ramend)
	out SPH,r22

	call inicio


ciclo:
	ldi temp,C 
	out PORTC,temp 				;display apresenta o C 

	sbis PIND,0 				;se o SW1 estiver pressionado entra em start
	rjmp start

	rjmp ciclo

start:

						;Inicialização da interrupção do TIMER0
	in r17,TIMSK
	ori r17,0b00000010 			;(ori para poderem ser alterados os restantes bits do registo sem ser alterado o bit número 1(começando a contagem de bits em 0))
	out TIMSK,r17

	ldi seg,0

start1:
	 sbis PIND,1				;Se o SW2 estiver pressionado entao stop
	 jmp stop
	 
	 brtc start1				; Testa se o T==1 vai avançar para o código seguinte caso seja significa que passou 100ms+- pois existe algum código a mais que fará com que haja falhas de tempo e os 10 segundos se transformem em 12 segundos
	 
	 clt	        				; Coloca T=0 
	 
	 dec cnt2
	 brne start1    				;se cnt2!=0 entra em start1 (volta ao inicio da start1), desta forma repetindo 10 vezes a contagem de 100ms
	 ldi cnt2,10
	 
	 inc seg					;seg aumenta 1 pois já passou 1s
	 
	 cpi seg,10				; comparação entre segundos que passaram e 10 segundos caso seja igual irá ir para o display E
	 breq displayE
	 
	 call display
	 
	 jmp start1
	 
start2:
	ldi temp,0b00001110			; Definir o prescaler como 256
	out TCCR0,temp

	jmp start1
	 
stop:
	 ldi temp,0 				;O cronometro pára 
	 out TCCR0,temp

stop1:

	 sbis PIND,3 				;se o SW4 estiver pressionado entra na main (recomeça o cronometro)
	 jmp main
	 
	 sbis PIND,1 				;se o SW2 estiver pressionado entra em start2 (o cronometro recomeça de onde foi parado)
	 jmp start2
	 
	 rjmp stop1
	 
	
displayE:
	 ldi temp,E
	 out PORTC,temp 				;Aparece o E (de erro) no display
	 
	 rjmp reset
	 
reset:						;se entrou aqui a unica maneira de sair quando alcança o estado E é para a main (cronometro volta a C para depois recomeçar a contagem quando se toque no SW1)
	 sbis PIND,3 				;se SW4 estiver pressionado entra em main (cronometro resetado)
	 jmp main
	 
	 jmp reset
	    
int_TIMER0:
	       in temp_int,SREG			;

	       dec cnt1
	       brne END_TIMER0 			;se cnt1!=0 entra em END_TIMER0 se cnt1==0 quer dizer que se passaram 100ms
	       ldi cnt1,50
	       
	       out SREG,temp_int
	       
	       set				; T=1
	       reti				; retorna e coloca o I = 1

END_TIMER0:
	    out SREG,temp_int
	    reti 

display:
	    ldi ZL, low(table<<1)
	    ldi ZH, high(table<<1)
	    
	    add ZL,seg
	    
	    ldi r16,0
	    adc ZH,r16
	    
	    lpm r10,Z
	    out PORTC,r10
	    
ret