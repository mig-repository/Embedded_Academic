#include <avr/interrupt.h>
#include <stdint.h>
#include <util/delay.h>
#define F_CPU 16000000UL
#include <stdio.h>
#include <string.h>

/* Switchs -> porto A
   Display -> porto C
   Motor   -> porto B

   P  ->  Motor parado
   I  ->  Inversão de sentido
   3  ->  30% de velocidade
   7  ->  70% de velocidade
   +  ->  incrementa 5% de velocidade
   -  ->  decrementa 5% de velocidade

   C  <-  Faz o pedido do valor do duty em percentagem

   Baud Rate = 19	200 bps
   8 bits dados e 1 stop bit

   ADC = 10 bits
*/

const unsigned char tabela[] = {0xC0,0xF9,0xA4,0xB0,0x99,0x92,0x82,0xF8,0x80,0x90,0xFF,0x8E,0xBF,0x87,0x8C};
/*								 0     1    2    3    4    5    6    7    8   9  apagado F	 -	  t     P                   */

typedef struct USARTRX
{
    char receiver_buffer;
    unsigned char status;
    unsigned char receive: 1;	// Reserva 1 bit
    unsigned char error: 1;		// Reerva 1 bit

}USARTRX_st;
volatile USARTRX_st rxUSART = {0,0,0,0}; 			// Inicializar a vari�vel
char transmit_buffer[10];


unsigned char vect_disp[4] = {10,0,11,11}, aux;			    // Para o display mostrar OFF no in�cio
unsigned char cnt_disp=0, Botao, duty=0, sentido=1, motor=0b01000000;	// O sentio inicial est� definido como hor�rio
volatile unsigned char CONT_500=100, flag_timer=0, flag_interrupt=0;	// Para contar 500 ms para fazer a invers�o do motor
long valor_final;

extern void ler_adc(void);

void inicio(void)									            //Configuracao dos PORTs e do USART1
{
    DDRA=0b11000000;								// Switchs como entradas e muktiplexer dos displays como saida
    PORTA=0b11000000;								// Desativa pull-ups internos dos switchs e ativa o display mais � direita (indiferente)
    DDRC=0b11111111;								// Display como sa�das
    DDRB=0b11111111;								// Motor como sa�das

    OCR0=77;										// Tempo base 5 ms
    TCCR0=0b00001111;								// Prescaler 1024
    TIMSK=0b00000010;								// Interrup��o por compara��o

    OCR2=0;
    TCCR2=0b01100011;								// Prescaler 64 - Modo PWM - Limpa OC2 ao comparar

    SREG=SREG|0x80;									// � igual a colocar SREG|=0x80;

    //Determin���o do Baud rate -> UBRR1
    UBRR1H = 0;										// USART1
    UBRR1L = 103;									// Baud Rate = 19200 bps (Erro=0.2%).

    //Configuracao da velocidade-> UCSR1A
    UCSR1A = (1<<U2X1);								// Coloca o bit de U2X1 a 1. Modo de operacao: Assincrono double speed.

    //Configuracao das dire�oes e interrup�oes-> UCSR1B
    UCSR1B = (1<<RXCIE1)|(1<<RXEN1)|(1<<TXEN1);		// RXCIE1: Habilita interrup��es na rece��o; RXEN1: Habilita rece��o; TXEN1: Habilita transmiss�o.

    //Configuracao do modo de envio e dete��o de erros-> UCSR1C
    UCSR1C = (1<<UCSZ11)|(1<<UCSZ10); 				// UCSZ11 e UCSZ10 a 1 fica: 8bit de dados. Default: Modo assincrono, sem paridade, 1 stop bit.

    ADCSRA = 0b10000111;						    // ativar o ADC, com factor 128 (f=125kHz), sem interrupcao, leitura singular
    ADMUX = 0b00000010;							    // Tensao Aref, leitura justificada a direita (leitura de 10 bits), canal AD2

    sei();											// Habilita interrup��es
}

void display(void)												//Rotina de alternancia para display diferente a cada 5ms.
{
    PORTC = 0xFF;							// Desliga o display.
    PORTA = cnt_disp << 6;					// Coloca os 2 bits que decidem o display que liga no extremo esquerdo do byte do porto A.
    PORTC = tabela[vect_disp[cnt_disp]];	// Imprime o valor de cada display de 5 em 5 ms. As posi��es 0,1,2,3 do vector vect_disp[] ir�o apontar para o hexadecimal do numero que quero apresentar.

    cnt_disp ++;							// 00(0) -> 01(1) -> 10(2) -> 11(3) -> Reset(00)

    if (cnt_disp == 4)
    {
        cnt_disp = 0;
    }
}

void processar_display(void)									//Exibicao dos display.
{
    if (duty == 0)						//Se estiver a zero exibo a palavra STOP.
    {
        vect_disp[0] = 5;				// Letra S
        vect_disp[1] = 13;				// Letra t
        vect_disp[2] = 0;				// Letra O
        vect_disp[3] = 14;				// Letra P
    }

    if (duty == 100)
    {
        if (sentido == 0)				// Sentido anti-hor�rio
        {
            vect_disp[0] = 12;			// Mostra o sinal menos (-)
        }
        else							// Sentido hor�rio
        {
            vect_disp[0] = 10;			// Apagado
        }

        vect_disp[1] = 1;				// N�mero 1
        vect_disp[2] = 0;				// N�mero 0
        vect_disp[3] = 0;				// N�mero 0
    }

    if (duty > 0 && duty < 10)
    {
        vect_disp[0] = 10;				// Apagado
        vect_disp[1] = 10;				// Apagado

        if (sentido == 0)				// Sentido anti-hor�rio
        {
            vect_disp[2] = 12;			// Mostra sinal menos (-)
        }
        else							// Sentido hor�rio
        {
            vect_disp[2] = 10;			// Apagado
        }

        vect_disp[3] = duty;			// Mostra n�mero correspondente
    }

    if (duty >=10 && duty < 100)
    {
        vect_disp[0] = 10;				// Apagado

        if (sentido == 0)				// Sentido anti-hor�rio
        {
            vect_disp[1] = 12;			// Mostra sinal menos (-)
        }
        else							// Sentido hor�rio
        {
            vect_disp[1] = 10;			// Apagado
        }

        vect_disp[2] = (duty/10);		// Mostra n�mero (dezenas)
        vect_disp[3] = (duty%10);		// Mostra n�mero (unidades)
    }
}

void ler_switch(void)											//Leitura de switch's.
{
    Botao = PINA & 0b00011111;									// Ler qual dos 5 primeiros switch's est� a ser pressionado.

    switch (Botao)
    {
        case 0b00011110:										// Caso seja o switch 1 -> Incrementa 5%.

            if (duty < 100)										// S� incrementa se o duty for menor que 100.
            {
                if (sentido == 1)								// O motor s� arranca premindo este Botao e como foi definido
                {												// acima que o sentido inicial � o hor�rio
                    PORTB = 0b11000000;							// ent�o o motor rodar� nesse sentido
                }

                duty = duty + 5;								// Incrementa 5 unidades percetuais.
                OCR2 = ((duty * 255)/100) ;						// Atualiza o OCR2 - PWM do motor.
            }

            processar_display();

            while ((PINA & 0b00011111) == 0b00011110)			// So avan�a se o bot�o ja nao estiver pressionado.
            {

            }

            break;
        case 0b00011101:									// Caso seja o switch 2 -> Decrementa 5%.

            if (duty > 0)										// S� decrementa se o duty for maior que 0.
            {
                duty = duty - 5;								// Decrementa 5 unidades percentuais.
                OCR2 = ((duty * 255)/100) ;						// Atualiza o OCR2 - PWM do motor.
            }

            processar_display();

            while ((PINA & 0b00011111) == 0b00011101)			// So avan�a se o bot�o ja nao estiver pressionado.
            {

            }

            break;
        case 0b00011011:									// Caso seja o switch 3 -> Coloca a rodar no sentido horario.

            if (sentido == 0)									// Se o motor estiver a rodar no sentido anti-hor�rio
            {
                PORTB = 0b00000000;								// Motor sem alimenta��o e for�ado a parar

                flag_interrupt = 1;								// Flag que vai dar informa��o na interrup��o do timer
                // de que � preciso iniciar a contar 500 ms.

                while (flag_timer != 1)							// Flag que d� a certeza de que o programa passou no timer
                {												// e s� continua depois de na interrup��o do timer esta flag
                    // passar a 1
                }

                while(CONT_500)									// P�ra o motor durante 500 ms enquanto CNT_500 for diferente de zero.
                {

                }

                CONT_500 = 100;									// Atualiza o contador para 500 ms
                flag_interrupt = 0;								// Limpa flag
                flag_timer = 0;									// Limpa flag

                PORTB = 0b11000000;								// Coloca o motor a rodar no sentido hor�rio
                sentido = 1;									// Coloca a flag do motor a rodar no sentido hor�rio
            }

            processar_display();

            break;
        case 0b00010111:									// Caso seja o switch 4 -> Coloca a rodar no sentido anti-horario.

            if (sentido == 1)									// Se o motor estiver a rodar no sentido hor�rio
            {
                PORTB = 0b00000000;								// Motor sem alimenta��o e for�ado a parar

                flag_interrupt = 1;								// Flag que vai dar informa��o na interrup��o do timer
                // de que � preciso iniciar a contar 500 ms
                while (flag_timer != 1)							// Flag que d� a certeza de que o programa passou no timer
                {												// e s� continua depois de na interrup��o do timer esta flag
                    // passar a 1
                }
                while(CONT_500)									// P�ra o motor 500 ms
                {
                }
                CONT_500 = 100;									// Atualiza contador para 500 ms
                flag_interrupt = 0;								// Limpa flag
                flag_timer = 0;									// Limpa flag

                PORTB = 0b10100000;								// Coloca o motor a rodar no sentido anti-hor�rio
                sentido = 0;									// Atualiza a flag do sentido do motor para anti-hor�rio
            }

            processar_display();

            break;
        case 0b00001111:									// Caso seja o switch 5 -> Motor para.

            OCR2 = 0;											// O motor fica sem alimenta��o
            duty = 0;											// O duty � tamb�m nulo

            processar_display();

            break;
    }
}

void send_message_string(char *buffer)						    //Envio de uma string.
{
    unsigned char i=0;
    while (buffer[i]!='\0')									// Testa se string chegou ao fim.
    {
        while((UCSR1A & (1<<UDRE1))==0);						// Verificar se buffer transmiss�o est� vazio.
        UDR1 = buffer[i];										//Coloca um byte no registo de transmiss�o.
        i++;
    }
}

void ler_dado_recebido(void)
{
    switch (rxUSART.receiver_buffer)
    {
        case 'P':
        case 'p':												// Motor parado

            duty = 0;
            OCR2 = 0;											// O motor fica sem alimenta��o
            // O duty � tamb�m nulo

            processar_display();
            break;

        case 'I':
        case 'i':
            aux = duty;
            duty = 0;
            _delay(500);
            PORTB ^= PORTB(1<<5);
            PORTB ^= PORTB(1<<6);
            duty = aux;
            OCR2 = ((duty * 255)/100);
            processar_display();
            break;

        case '3':												// 30% de velocidade

            duty = 30;
            OCR2 = ((duty * 255)/100) ;							// Atualiza o OCR2 - PWM do motor

            processar_display();								// Atualizar display
            break;

        case '7':												// 70% de velocidade

            duty = 70;
            OCR2 = ((duty * 255)/100) ;							// Atualiza o OCR2 - PWM do motor

            processar_display();								// Atualizar display
            break;

        case '+':												// Incremente 5% de velocidade

            if (duty < 100)										// S� incremente se o dutty for menor que 100
            {
                if (sentido == 1)								// O motor s� arranca premindo este button e como foi definido
                {												// acima que o sentido inicial � o hor�rio
                    PORTB = 0b11000000;							// ent�o o motor rodar� nesse sentido
                }

                duty = duty + 5;								// Incrementa 5% de velocidade.
                OCR2 = ((duty * 255)/100) ;						// Atualiza o OCR2 - PWM do motor
            }

            processar_display();
            break;

        case '-':												// Decrementa 5% de velocidade.

            if (duty > 0)										// S� decrementa se o duty for maior que 0
            {
                duty = duty - 5;								// Decrementa 5 unid
                OCR2 = ((duty * 255)/100) ;						// Atualiza o OCR2 - PWM do motor
            }

            processar_display();
            break;

        case 'c':
        case 'C':												// Pedido de envio do duty cycle

            sprintf(transmit_buffer, "Duty Cycle = %d\r\n", duty);
            send_message_string(transmit_buffer);

            break;

    }
}

void send_message_byte(char data)								//Envio de 1 byte.
{
    while((UCSR1A & (1<<UDRE1))==0);
    UDR1 = data;
}

ISR(TIMER0_COMP_vect)											//Interrupcao do timer.
        {
                display();										// Atualiza display de 5 em 5 ms.

        if (flag_interrupt == 1)							    // Flag ativa se houver um pedido de inversao de sentido do motor.
        {
            flag_timer = 1;											// Flag ativa para indicar na rotina dos Botoes que o programa entrou na
            CONT_500 --;											// Interrup��o do timer e come�a a contar os 500 ms
        }
        }

ISR (USART1_RX_vect)											//Interrupcao da comunicacao serie - USART.
        {
                rxUSART.status = UCSR1A;									// Guarda flags de erros

        if (rxUSART.status & ((1<<FE1)|(1<<DOR1)|(1<<UPE1))) 		// Verifica erros na recepcao
        {
            rxUSART.error = 1;										// Ativa flag de erro
        }

        rxUSART.receiver_buffer = UDR1;								// Guarda o valor que chegou no campo da estrutura 'rxUSART' chamado receiver_buffer.
        rxUSART.receive = 1; 										// Ativa flag para avisar que chegou algum valor.
        }

int main(void)
{
    inicio();
    sprintf(transmit_buffer, "Duty Cycle = %d\r\n", 55);
    send_message_string(transmit_buffer);

    while (1)
    {
        if (rxUSART.receive == 1)                   // Verifica se recebeu algum dado e se nao tem erros.
        {
            if (rxUSART.error == 1)                 // Verifica se existe algum erro.
            {
                // Procedimentos para resolver erros.
                sprintf(transmit_buffer, "Erro na recepção de dados!\r\n");
                rxUSART.error = 0;                  // Limpa flag de erro na recepcao
            }

            switch (rxUSART.receiver_buffer)
            {
                case 's':
                case 'S':
                    ler_switch();                        // le qual o butao premido.
                    break;
                case 'd':
                case 'D':
                    ler_dado_recebido();                // Executa as accoes consoante a tecla enviada pelo pc.
                    break;
                case 'a':
                case 'A':
                    unsigned char leituraL, leituraH;

                    ler_adc();                                        // funcao adc assembly
                    valor_final = ((leituraH << 8) + leituraL);       // soma H + L

                    duty = (valor_final * 100) / 1023;              // escalar valor final para range de 0 a 100
                    OCR2 = ((duty * 255) / 100);                    // aplicar no ocr

                    if ((PINA & 0b00011111) ==
                        0b00001111)            // Se for pressionado o Switch 5, inverte o sentido do motor
                    {
                        aux = duty;
                        duty = 0;                                   // parar o motor
                        _delay(500);                                // 500 ms de espera
                        PORTB ^= PORTB(1 << 5);                       // inverter pino 5
                        PORTB ^= PORTB(1 << 6);                       // inverter pino 6
                        duty = aux;                                 // reestablecer valor inicial do dutty cicle
                        OCR2 = ((duty * 255) / 100);
                    }

                    processar_display();
            }

            rxUSART.receive = 0;                    // Limpa flag de aviso de recepcao de dados.
        }
    }
}