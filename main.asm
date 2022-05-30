#include <avr/interrupt.h>

.extern leituraH                        // enderecos de memoria a serem partilhados
.extern leituraL

.global ler_adc                         // funcao assembly a ser chamada no programa em C

ler_adc:	push	r19
            push	r20
            push	r21

            clr		r19
            clr		r20
            clr		r21

            ldi		r16, 4

inicio:	    sbi		ADCSRA, 6           // Inicio da conversao AD

wait:   	sbic	ADCSRA, 6
            jmp		wait

            in		r19, ADCL
            Add		r20, r19
            in		r19, ADCH
            Adc		r21, r19

            dec		r16
            brne	inicio

            ldi		r16, 2

divisao:    lsr		r21
            ror		r20

            dec		r16
            brne	divisao

            sts		leituraL, r20                   // escrita namemoria de dados (L e H)
            sts		leituraH, r21

            pop		r21
            pop		r20
            pop		r19
            pop		r16

            ret






