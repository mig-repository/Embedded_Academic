; Funcionamento 5


.include<m128def.inc>

.def	pointer=	r10
.def	temp=		r16
.def	int_flag=	r17
.def	dig_tempo=	r18
.def	estado=		r19
.def	nr_rot=		r20
.def	ps_time=	r21
.def	cnt_2ms=	r22
.def	cnt_int0=	r23
.def	cnt_int1=	r24
.def	cnt_int2=	r25

.equ	c_zero=		0xC0							;	ConfiguraÁıes dos caracteres para o display
.equ	c_um=		0xF9
.equ	c_dois=		0xA4
.equ	c_tres=		0xB0
.equ	c_quatro=	0x99
.equ	c_cinco=	0x92
.equ	c_seis=		0x82
.equ	c_sete=		0xF8
.equ	c_oito=		0x80
.equ	c_nove=		0x90
.equ	c_p_zero=	0x40
.equ	c_p_um=		0x79
.equ	c_p_dois=	0x24
.equ	c_p_tres=	0x30
.equ	c_p_quatro=	0x19
.equ	c_p_cinco=	0x12
.equ	c_p_seis=	0x02
.equ	c_p_sete=	0x78
.equ	c_p_oito=	0x00
.equ	c_p_nove=	0x10
.equ	c_letra_e=	0x86
.equ	c_off=		0xFF

.equ	_500ms=		0xFA
.equ	_100ms=		0x32
.equ	standby=	0							;	ESTADO INICIAL		-> Acende o 0 e espera por SW1
.equ	running=	1							;	ESTADO DECREMENTO	-> Decrementa o display
.equ	pause=		2							;	ESTADO DE PAUSA		-> Depois de carregar 1x em SW2, espera por 2™ Pulso ou 10s
.equ	finish=		3							;	ESTADO FINAL		-> Pisca 3 vezes e volta ao inÌcio
.equ	error=		4							;	ESTADO DE ERRO		-> D· sinal de erro E, pisca 3x e volta ao inÌcio

										; ESTA VERS√O PRETENDE CRIAR UM DEBOUNCING NA LEITURA DOS BOT’ES
										; ALTERAR AS ZONAS DA MEMORIA DOS VETORES
.cseg
.org	0x0000									;	Define o inicio de um segmento de cÛdigo
	jmp	main								;	OperaÁ„o de RESET
.org	0x0002									;	Vetor interrupÁ„o INT0
	jmp	int_sw1								;	SW1 - START
.org	0x0004									;	Vetor interrupÁ„o INT1
	jmp	int_sw2								;	SW2 - STOP
.org	0x001E									;	Vetor interrupÁ„o TC0
	jmp	int_tc0
.org	0x0046

table:
.db		c_zero, c_um, c_dois, c_tres, c_quatro, c_cinco, c_seis, c_sete, c_oito, c_nove, c_p_zero, c_p_um, c_p_dois, c_p_tres, c_p_quatro, c_p_cinco, c_p_seis, c_p_sete, c_p_oito, c_p_nove, c_off, c_letra_e

inic:
										;	Inicializar os Portos
	ldi	temp,		0b11000000					;	Configurar o porto D para os SW e LCD da DIR
	out	ddrd,		temp
	out	portd,		temp

	ser	temp								;	Configurar o porto C para o LCD
	out	ddrc,		temp

										;	ConfiguraÁ„o do Timer 0
	ldi	temp,		249						;	Configurar para 2ms
	out	OCR0,		temp						;	Valor para a comparaÁ„o

	ldi	cnt_2ms,	100						;	Contador carregado inicialmente com 100
	ldi	cnt_int0,	0						;	Contador carregado inicialmente com 0
	ldi	cnt_int1,	0						;	Contador carregado inicialmente com 0
	ldi	cnt_int2,	6						;	Contador carregado inicialmente com 6


	ldi	temp,		0b00001101					;	TC0 no modo CTC, com prescaler de 128 e OC0 desligado
	out	TCCR0,		temp

										;	ConfiguraÁ„o das InterrupÁıes do Timer
	in	temp,		TIMSK						;	Ler o valor do Registo TIMSK
	ori	temp,		0b00000010					;	Colocar m·scara para activar a interrupÁ„o do TC0
	out	TIMSK,		temp						;	Escrever no registo as configuraÁıes

											; 	ConfiguraÁ„o das InterrupÁıes Externas
	ldi	temp,	0b00001010						;	Flanco Descendente em Ambos
	sts	eicra,	temp
	ldi	temp,	0b00000001						;	Inicia apenas com a interrupÁ„o do SW1 activa
	out	eimsk,	temp

	ldi	estado,		standby
	clr	dig_tempo							;	Garantir que o car·cter inicial È o 0
	clt									;	Garantir que a Flag T inicia a 0
	sei									;	Habilitar globalmente as interrupÁıes

	ret

main:
										;	Configurar a STACK
	ldi	temp,		low(RAMEND)
	out	spl,		temp
	ldi	temp,		high(RAMEND)
	out	sph,		temp

	call inic								;	Correr a rotina de inÌcio

est_inic:
	call	sel_disp							;	FunÁ„o que selecciona o display
	call	display								;	Atualiza o display
	jmp	est_inic

e_standby:
	sbrc	int_flag,	1						;	Valida se o SW1 est· de facto pressionado
	call	sw1_valido

	sbrc	int_flag,	0
	call	sw1_valido
	ret

e_running:
	sbrc	int_flag,	1						;	Valida se o SW1 est· de facto pressionado
	call	sw2_valido

	sbrc	int_flag,	0
	call	sw2_valido
e_run_ex:
	brts	dec_tot								;	Enquanto n„o terminar a temporizaÁ„o, mantÈm o display com o valor atual
	ret

dec_tot:
	push	nr_rot
	clr	nr_rot
	clt									;	Decrementar ‡ taxa de 1s
	ldi	cnt_2ms,	_100ms

	call	check_disp

										;	Testar todas as possibilidades para os estados dos displays

										;	#	x2	x1	x0	Executa
										;	0	0	0	0	Carrega as definiÁıes do estado finish
										;	1	0	0	1	Decrementa x0
										;	2	0	1	0	Decrementa x1 && x0=9
										;	3	0	1	1	Decrementa x0
										;	4	1	0	0	Decrementa x2 && Atribuir: x1=9 && x0=9
										;	5	1	0	1	Decrementa x0
										;	6	1	1	0	Decrementa x1 && x0=9
										;	7	1	1	1	Decrementa x0
										;	**	x2 = cnt_int2
										;	**	x1 = cnt_int1
										;	**	x0 = cnt_int0

										;	O tst_0 atÈ ao tst_7 implementa esta "tabela de verdade"


tst_0:
	cpi	nr_rot,		0
	breq	r_decres

tst_1:
	ldi	temp,		1
	cpse	nr_rot,		temp
	jmp	tst_2
	dec	cnt_int0
	jmp	fim_dec_tot

tst_2:
	ldi	temp,		2
	cpse	nr_rot,		temp
	jmp	tst_3
	dec	cnt_int1
	ldi	cnt_int0,	9
	jmp	fim_dec_tot

tst_3:
	ldi	temp,		3
	cpse	nr_rot,		temp
	jmp	tst_4
	dec	cnt_int0
	jmp	fim_dec_tot

tst_4:
	ldi	temp,		4
	cpse	nr_rot,		temp
	jmp	tst_5
	dec	cnt_int2
	ldi	cnt_int1,	9
	ldi	cnt_int0,	9
	jmp	fim_dec_tot

tst_5:
	ldi	temp,		5
	cpse	nr_rot,		temp
	jmp	tst_6
	dec	cnt_int0
	jmp	fim_dec_tot

tst_6:
	ldi	temp,		6
	cpse	nr_rot,		temp
	jmp	tst_7
	dec	cnt_int1
	ldi	cnt_int0,	9
	jmp	fim_dec_tot

tst_7:
	ldi	temp,		7
	cpse	nr_rot,		temp
	jmp	fim_dec_tot
	dec	cnt_int0

fim_dec_tot:
	pop	nr_rot
	ret

check_disp:										;	Verifica se h· algum display com 0
	ldi	temp,		0							;	Atribui os imputs para a tabela de verdade posterior ao teste
	cpse	cnt_int2,	temp
	ori	nr_rot,		0b00000100
	cpse	cnt_int1,	temp
	ori	nr_rot,		0b00000010
	cpse	cnt_int0,	temp
	ori	nr_rot,		0b00000001
	ret

r_decres:
	pop	nr_rot
	ldi	nr_rot,		6
	ldi	temp,		0b00000000						;	Desactiva as interrupÁıes do SW1 e SW2
	out	eimsk,		temp
	ser	temp
	out	eifr,		temp							;	Limpar as FLAGS de InterrupÁıes
	ldi	estado,		finish							;	Mudar o estado para FINISH
	ldi	cnt_2ms,	_500ms
												;	Carregar os displays com valor 00.0
	ldi	cnt_int0,	20							;	Caso pretendesse que fosse:	 ___     ___     ___
	ldi	cnt_int1,	20							;									|___|   |___|   |___
	ldi	cnt_int2,	20							;
												;	Bastava que fosse cnt_int0=0; cnt_int1=10; cnt_int2=0
	jmp	e_run_ex								;	E na funÁ„o f_0_piscar, alterar para sbic

e_pause:
	sbrc	int_flag,	1							;	Verifica se o bot„o SW2 est· pressionado
	call	sw2_valido

	sbrc	int_flag,	0
	call	sw2_valido

e_pause_ex:
	brts	dec_10s									;	Enquanto n„o terminar a temporizaÁ„o, mantÈm o display com o valor atual
	ret

dec_10s:
	dec	nr_rot									;	Decrementa o valor do car·cter a apresentar
	clt
	ldi	cnt_2ms,	_500ms
	cpi	nr_rot,		0
	brne	e_pause_ex								;	Enquanto n„o for 0, continua a piscar

	ldi	nr_rot,		6
	ldi	cnt_int0,	21							;	Carregar a letra E para ser mostrada
	ldi	cnt_int1,	20
	ldi	cnt_int2,	20
	ldi	temp,		0b00000000						;	Desactiva as interrupÁıes do SW1 e SW2
	out	eimsk,		temp
	ser	temp
	out	eifr,		temp							;	Limpar as FLAGS de InterrupÁıes
	ldi	estado,		error							;	Mudar o estado para ERROR
	ret

e_finish:
	brts	f_0_piscar								;	Enquanto n„o terminar a temporizaÁ„o, mantÈm o display com o valor atual
	ret

f_0_piscar:
	dec	nr_rot									;	Decrementa o valor do car·cter a apresentar
	ldi	cnt_2ms,	_500ms
	clt
	ldi	temp,		20							;	Carrega o valor para desligar e ligar de acordo com o XOR
	eor	cnt_int0,	temp							;	Ligar ou desligar o display das dÈcimas

	ldi	cnt_int1,	10							;	Liga ou desliga o display das unidades, de acordo com nr_rot
	sbrs	nr_rot,		0							;	Se for para inverter a fase, fica sbic
	ldi	cnt_int1,	20

	ldi	temp,		20							;	Carrega o valor para desligar e ligar de acordo com o XOR
	eor	cnt_int2,	temp							;	Ligar ou desligar o display	das dezenas

	cpi	nr_rot,	0								;	Levantar a flag de ZERO
	brne	e_finish								;	Enquanto n„o chegar a 0, continua a decrementar

	ldi	temp,		0b00000001						;	Ativa apenas a interrupÁ„o do SW1
	out	eimsk,		temp
	ser	temp
	out	eifr,		temp							;	Limpar as FLAGS de InterrupÁıes

	ldi	cnt_int0,	0							;	Carregar os displays com 60.0
	ldi	cnt_int1,	0
	ldi	cnt_int2,	6

	ldi	estado,		standby
	ret

e_error:
	brts	e_blink									;	Enquanto n„o terminar a temporizaÁ„o, mantÈm o display com o valor atual
	ret	

e_blink:
	dec	nr_rot									;	Decrementa o valor do car·cter a apresentar
	ldi	cnt_2ms,	_500ms
	clt

;	CASO SE PRETENDA QUE O E PISQUE
;	ldi		temp,		0b00000001					;	Carrega o valor para desligar e ligar de acordo com o AND
;	and		temp,		nr_rot						;	Guarda em temp o valor do bit 0 de nr_rot
;	andi	cnt_int0,	0b11111110
;	adc		cnt_int0,	temp						;	Ligar ou desligar o display
;

	cpi	nr_rot,		0							;	Levantar a flag de ZERO
	brne	e_error									;	Enquanto n„o chegar a 0, continua a decrementar

											;	Carrega das definiÁıes para entrar no modo standby

	ldi	temp,		0b00000001						;	Ativa apenas a interrupÁ„o do SW1
	out	eimsk,		temp
	ser	temp
	out	eifr,		temp							;	Limpar as FLAGS de InterrupÁıes

	ldi	cnt_int0,	0							;	Carregar os displays com 60.0
	ldi	cnt_int1,	0
	ldi	cnt_int2,	6

	ldi	estado,		standby
	ret

											;	FunÁ„o para seleccionar o display a atualizar a cada 2ms
											;
											;	#	Valor CNT	Executa
											;	0		00		Selecciona o display das DÈcimas
											;	1		01		Selecciona o display das Dezenas
											;	2		10		Selecciona o display das Unidades
											;	3		11		Selecciona o display das DÈcimas
											;
											;	**	Optou-se por atualizar mais frequentemente o display das DÈcimas, dado que varia mais r·pido
											;	**	Aproveitou-se o estado dos ˙ltimos 2 bits do CNT_2MS, dado que se repetem a cada 4 decrementos,
											;		criando, dessa forma, um ciclo de refresh dos 3 displays de 8ms (125 hz).


sel_disp:
	mov	temp,		cnt_2ms							;	Copiar a informaÁ„o de cnt_2ms para retirar os bits menos significativos
	andi	temp,		0b00000011							;	Retirar apenas os ˙ltimos 2 bits, guardando em temp
	cpi	temp,		1							;	Verificar se o n˙mero È 1
	brne	testa_2										;	Caso n„o seja vai testar se È 2
	in	temp,		portd							;	Copia o estado do porto D para temp
	andi	temp,		0b00111111							;	Guarda a informaÁ„o dos 6 bits menos significativos
	ori	temp,		0b01000000						;	Muda o estado dos 2 bits mais significativos para seleccionar o display
	out	portd,		temp							;	Escreve o resultado no Porto D
	mov	dig_tempo,	cnt_int2						;	Copia o conte˙do de cnt_int2 para apresentaÁ„o no display

	ret

testa_2:
	cpi	temp,		2							;	Verificar se o n˙mero È 2
	brne	sel_dec										;	Caso n„o seja, vai para a funÁ„o que selecciona o display das DÈcimas
	in	temp,		portd							;	Copia o estado do porto D para temp
	andi	temp,		0b00111111							;	Guarda a informaÁ„o dos 6 bits menos significativos
	ori	temp,		0b10000000						;	Muda o estado dos 2 bits mais significativos para seleccionar o display
	out	portd,		temp							;	Escreve o resultado no Porto D
	mov	dig_tempo,	cnt_int1						;	Copia o conte˙do de cnt_int1 para apresentaÁ„o no display
	ldi	temp,		finish							;	Compara-se o estado com finish
	cpse	estado,		temp								;	Se for mantÈm o valor
	jmp	testa_2_c
	ret

testa_2_c:
	ldi	temp,		10							;	Carrega o valor com ponto (dado que È o display das unidades) para somar ao dig_tempo
	adc	dig_tempo,	temp							;	Considerar que na table escrita na mem de prog, Valor + 10, acrescenta o ponto
	cpi	estado,		error							;	Se estiver no estado ERROR, apresenta apenas o E
	breq	m_pt_err									;	Desligando os outros displays e retiranto o ponto
	ldi	temp,		pause							;	Se estiver no estado PAUSE, apresenta o ponto de
	cpse	estado,		temp								;	500 em 500 ms (freq. 1hz)
	ret
	call	m_ponto

	ret

sel_dec:										;	Como n„o È 2 nem 1, selecciona o display das dÈcimas
	in	temp,		portd
	andi	temp,		0b00111111
	ori	temp,		0b11000000
	out	portd,		temp
	mov	dig_tempo,	cnt_int0

	ret

display:
											;   Z:0x00XX => posiÁ„o onde inicia a tabela
	ldi	ZL,			low(table<<1)					;	Multiplica a posiÁ„o do apontador por 2
	ldi	ZH,			high(table<<1)
	add	ZL,			dig_tempo					;	Adiciona o valor do digito do tempo ao apontador ZL
	ldi	temp,		0
	adc	ZH,			temp						;	Adiciona 0 ao carry
	lpm	pointer,	Z							;	Carrega para o registo o valor apontado por Z
	out	portc,		pointer
	ret

m_ponto:
											;	Se nr_rot for PAR, mostra o ponto. IMPAR, oculta
	sbrc	nr_rot,		0							;	Verifica se È PAR ou IMPAR
	ret										;	Se IMPAR, mostra o valor atual
m_pt_err:
	ldi	temp,		10
	sub	dig_tempo,	temp							;	Se PAR, subtrai 10
	ret

int_sw1:
	push	temp									;	Envia para a STACK o valor de temp
	in	temp,		sreg							;	Guarda o estado do SREG em temp
	push	temp									;	Envia o valor do SREG para stack

	ldi	temp,		0
	cpse	int_flag,	temp
	clr	int_flag								;	Limpa a flag
	inc	int_flag								;	Incrementa 1 ‡ flag

	pop	temp									;	Recupera o valor inicial de SREG
	out	sreg,		temp							;	Repoe o valor inicial em SREG
	pop	temp									;	Recupera o valor inicial de temp
	reti

sw1_valido:
	push	temp									;	Envia para a STACK o valor de temp
	in	temp,		sreg							;	Guarda o estado do SREG em temp
	push	temp									;	Envia o valor do SREG para stack

	sbic	pind,		0							;	LÍ o estado do SW1
	jmp	fim_sw1									;	Se for 0, incrementa 1 na flag
	inc	int_flag
	ldi	temp,		3							;	Se for 3 È porque houve interrupÁ„o e passados pelo menos 2ms ainda est· pressionado
	cpse	int_flag,	temp
	jmp	fim_sw1

	cpi	estado,		standby
	brne	fim_sw1
	ldi	estado,		running
	clt										;	Limpa a flag de T para iniciar nova contagem
	ldi	cnt_2ms,	_100ms							;	Carrega temporizaÁ„o de 1s
	ldi	cnt_int0,	9							;	Carregar 9 no display 3
	ldi	cnt_int1,	9							;	Carregar 9 no display 2
	ldi	cnt_int2,	5							;	Carregar 5 no display 1
	ldi	temp,		0b00000010						;	Ativa apenas a interrupÁ„o do SW2
	out	eimsk,		temp
	ser	temp
	out	eifr,		temp							;	Limpar as FLAGS de InterrupÁıes
	clr	int_flag

fim_sw1:
	pop	temp									;	Recupera o valor inicial de SREG
	out	sreg,		temp							;	Repoe o valor inicial em SREG
	pop	temp									;	Recupera o valor inicial de temp

	ret

int_sw2:
	push	temp									;	Envia para a STACK o valor de temp
	in	temp,		sreg							;	Guarda o estado do SREG em temp
	push	temp									;	Envia o valor do SREG para stack

	ldi	temp,		0
	cpse	int_flag,	temp
	clr	int_flag								;	Limpa a flag
	inc	int_flag								;	Incrementa 1 ‡ flag

	pop	temp									;	Recupera o valor inicial de SREG
	out	sreg,		temp							;	Repoe o valor inicial em SREG
	pop	temp									;	Recupera o valor inicial de temp
	reti


sw2_valido:
	push	temp									;	Envia para a STACK o valor de temp
	in	temp,		sreg							;	Guarda o estado do SREG em temp
	push	temp									;	Envia o valor do SREG para stack

	sbic	pind,		1							;	LÍ o estado do SW2
	jmp	fim_sw2									;	Se for 0, incrementa 1 na flag
	inc	int_flag
	ldi	temp,		3							;	Se for 3 È porque houve interrupÁ„o e passados pelo menos 2ms ainda est· pressionado
	cpse	int_flag,	temp
	jmp	fim_sw2

	ldi	temp,		pause
	cpse	estado,		temp							;	Se N√O estiver no estado pause, testa se est· em running
	jmp	testa_run

	cpi	nr_rot,		0							;	Verificar se j· passaram 10s
	breq	fim_sw2									;	Caso j· tenham passado 10s fica o estado anterior
	ldi	estado,		running							;	Caso ainda n„o tenham passado 10s, volta para running
	mov	cnt_2ms,	ps_time							;	Guarda o tempo do contador de 2ms
	mov	temp,		dig_tempo						;	Copia a informaÁ„o de dig_tempo para temp
	subi	temp,		10							;	Subtrai 10 ao digito para saber se tem ponto ou n„o
	brmi	fim_sw2									;	Se for negativo, mantÈm dig_tempo
	subi	dig_tempo,	10							;	Se for positivo, subtrai 10 ao dig_tempo (retirar o ponto)
	jmp	fim_sw2

testa_run:
	ldi	temp,		running
	cpse	estado,		temp							;	Se estiver no estado running, vai para pause
	jmp	fim_sw2
	mov	ps_time,	cnt_2ms
	ldi	estado,		pause
	clt										;	Limpa a flag de T para iniciar nova contagem
	ldi	nr_rot,		20
	ldi	cnt_2ms,	_500ms							;	Carrega temporizaÁ„o de 1s
	ldi	temp,		10
	adc	dig_tempo,	temp							;	Adicionar 10 ao digito para mostrar o ponto

fim_sw2:
	pop	temp									;	Recupera o valor inicial de SREG
	out	sreg,		r16							;	Repoe o valor inicial em SREG
	pop	temp									;	Recupera o valor inicial de temp
	reti

int_tc0:
	push	temp									;	Recupera o valor inicial de SREG
	in	temp,		sreg							;	Repoe o valor inicial em SREG
	push	temp									;	Recupera o valor inicial de temp

	dec	cnt_2ms									;	Decrementar o contador
	cpi	cnt_2ms,	0
	brne	v_stby									;	Enquanto n„o chegar a 0, faz return
	set										;	activa a flag T

											; Verificar e saltar para o estado atual

v_stby:
	ldi	temp,		standby
	cpse	estado,		temp
	jmp	v_run
	call	e_standby

v_run:
	ldi	temp,		running
	cpse	estado,		temp
	jmp	v_pause
	call	e_running

v_pause:
	ldi	temp,		pause
	cpse	estado,		temp
	jmp	v_finish
	call	e_pause

v_finish:
	ldi	temp,		finish
	cpse	estado,		temp
	jmp	v_error
	call	e_finish

v_error:
	ldi	temp,		error
	cpse	estado,		temp
	jmp	fim_int
	call	e_error

fim_int:
	pop	temp									;	Recupera o valor inicial de SREG
	out	sreg,		temp							;	Repoe o valor inicial em SREG
	pop	temp									;	Recupera o valor inicial de temp
	reti
