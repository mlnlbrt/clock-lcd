;
; ***********************************************
; * MLN CLK					*
; ***********************************************
; * Main program file                     	*
; ***********************************************
; * 31.01.2013 r., last change 06.04.2015 r.	*
; * (C) 2013, 2015 by Albert Malina 		*
; ***********************************************
;
.NOLIST
.INCLUDE "m16Adef.inc"
.LIST
;
; ============================================
;   I N F O   O   S P R Z E C I E
; ============================================
;
; Kod programu zostal przygotowany tak,
; ze obsluga wyswietlacza 3 i 1/2 cyfry 
; rozlozona jest na wszystkie porty MCU,
; przy czym czesc odpowiedzialna za cyfry
; 00-59 powinna byc na dwoch portach, a 
; czesc odpowiedzialna za cyfry 01-12 na 
; pozostalych dwoch. 
; Sterowanie (3 przyciski) moze byc obsadzone
; na dowolnych wolnych pinach jednego portu
; (tego samego). 
; MCU MUSI byc taktowane z kwarcu zegarkowego
; 32.768kHz. 
; Sygnal CLK wyswietlacza moze zostac zdefiniowany
; dowolnie, przy czym pin i port na ktorym
; zostanie on obsadzony musza zostac uwzgledione
; w plikach htable.inc i mtable.inc - na miejscu
; tego pinu ZAWSZE musi byc 0.
;
; ============================================
;  D E K L A R A C J E    S T A L Y C H
; ============================================
;
; przypisanie portu i pinu sygnalu CLK ekranu
.EQU CK_PORT	= PORTB
.EQU CK_PIN	= PB2
; przypisanie portu i pinu dwukropka
.EQU C_PORT	= PORTB
.EQU C_PIN	= PB3
; ustawienia klawiatury
.EQU BTN_PORT	= PORTB
.EQU BTN_PIN	= PINB
.EQU BTN_H	= PB5
.EQU BTN_M	= PB6
; ponizej zdefiniowane jest I/O portow
.EQU PORTA_IO	= 0b01111111
.EQU PORTB_IO	= 0b10011110 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!! (MAKRO?)
.EQU PORTC_IO	= 0b01111111
.EQU PORTD_IO	= 0b01111111
; tutaj podciagania 
.EQU PORTA_CFG	= 0b00000000
.EQU PORTB_CFG	= 0b01100000 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!! (MAKRO?)
.EQU PORTC_CFG	= 0b00000000
.EQU PORTD_CFG	= 0b00000000
; maski uzywane przy taktowaniu ekranu, 1 na miejscach spiecia z ekranem
.EQU PORTA_MASK	= 0b01111111
.EQU PORTB_MASK	= 0b00011110 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!! (MAKRO?)
.EQU PORTC_MASK	= 0b01111111
.EQU PORTD_MASK	= 0b01111111

; ustawienia bitow flag
.EQU UPDATE_REQ	= 0
.EQU BTN_LOCK	= 1
;
; ============================================
;   P R Z Y P I S A N I A   R E J E S T R O W
; ============================================
;
.DEF AMASK 	= R6
.DEF BMASK 	= R7
.DEF CMASK 	= R8
.DEF DMASK 	= R9
.DEF C_EOR	= R10
.DEF TPORTA 	= R11
.DEF TPORTB 	= R12
.DEF TPORTC 	= R13
.DEF TPORTD 	= R14
.DEF RSREG 	= R15
.DEF RMP 	= R16 
.DEF RMP2	= R17
.DEF TICKS 	= R18
.DEF TIME_S 	= R19
.DEF TIME_M	= R20
.DEF TIME_H	= R21
.DEF FLAGS	= R22
;
; ============================================
;       Z M I E N N E   W   R A M I E
; ============================================
;
.DSEG
.ORG  	0X0060
;
; ============================================
;   R E S E T   I   P R Z E R W A N I A
; ============================================
;
.CSEG
.ORG 	$0000
	jmp MAIN ; Reset vector
	reti ; Int vector 1
	nop
	reti ; Int vector 2
	nop
	reti ; Int vector 3
	nop
	reti ; Int vector 4
	nop
	reti ; Int vector 5
	nop
	reti ; Int vector 6
	nop
	reti ; Int vector 7
	nop
	reti ; Int vector 8
	nop
	rjmp ISR_T0OVF ; Int vector 9
	nop
	reti ; Int vector 10
	nop
	reti ; Int vector 11
	nop
	reti ; Int vector 12
	nop
	reti ; Int vector 13
	nop
	reti ; Int vector 14
	nop
	reti ; Int vector 15
	nop
	reti ; Int vector 16
	nop
	reti ; Int vector 17
	nop
	reti ; Int vector 18
	nop
	reti ; Int vector 19
	nop
	reti ; Int vector 20
	nop
;
; ============================================
;     O B S L U G A   P R Z E R W A N
; ============================================
;
ISR_T0OVF:
; rozpoczecie przerwania
; ****************
; 6 cykli wejscia w przerwanie
; maksymalnie ~50 cykli w srodku przerwania
; z reti wlacznie
; ****************
	in 	RSREG, 	SREG
	push	RMP
; ustawienie bajtu potrzebnego przy pozniejszych negacjach
	ser	RMP
; ****************
; pierwszy etap przerwania - odswiezanie wyswietlacza
; ****************
	eor 	TPORTA, AMASK
	eor 	TPORTB, BMASK
	eor 	TPORTC, CMASK
	eor 	TPORTD, DMASK
; zaaktualizowanie portow 
	out 	PORTA, 	TPORTA
	out 	PORTB, 	TPORTB
	out 	PORTC, 	TPORTC
	out 	PORTD, 	TPORTD
; ****************
; drugi etap przerwania - zwiekszanie zmiennej sekundowej
; ****************
	inc 	TICKS
	sbrs 	TICKS, 	7
	rjmp	ISR_T0OVF_END
	andi 	TICKS, 	0b01111111
; jesli nastepna linia sie wykona, to znaczy ze zegar 
; przepelnil sie 128-my raz, czyli minela jedna sekunda
ISR_T0OVF_SINCREASE:
	inc 	TIME_S
; obsluga dwukropka - niezalezna od reszty segmentow MAKRO!!!!!!!!!!!!!
	eor	TPORTB,	C_EOR
	cpi	TIME_S,	60
	brlo	ISR_T0OVF_END
; jesli licznik sekund byl rowny 60 to  
; nastepuje inkrementacja licznika minut
; oraz odswiezenie zawartosci wyswietlacza
ISR_T0OVF_MINCREASE:
	ldi	TIME_S,	0b00000000
	inc	TIME_M
	sbr	FLAGS,	(1 << UPDATE_REQ)
	cpi	TIME_M,	60
	brlo	ISR_T0OVF_END
ISR_T0OVF_HINCREASE:
	ldi	TIME_M, 0b00000000
	inc	TIME_H
	cpi	TIME_H,	24
	brlo	ISR_T0OVF_END
ISR_T0OVF_HOVERFLOW:
	ldi	TIME_H,	0b00000000
ISR_T0OVF_END:
; przywrocenie stanu sprzed przerwania i opuszczenie go
	pop	RMP
	out 	SREG, 	RSREG
	reti
;
; ============================================
;    	KONFIGURACJA WYSWIETLACZA
; ============================================
;
.NOLIST
.INCLUDE "htable.inc"
.INCLUDE "mtable.inc"
.LIST
;
; ============================================
;     I N I C J A L I Z A C J A 
; ============================================
;
Main:
; Init stosu
	ldi 	RMP, 	HIGH(RAMEND) 
	out 	SPH, 	RMP
	ldi 	RMP, 	LOW(RAMEND)
	out 	SPL, 	RMP
; Init Portu A
	ldi 	RMP, 	PORTA_IO
	out 	DDRA, 	RMP
	ldi 	RMP, 	PORTA_CFG
	out 	PORTA, 	RMP
; Init Portu B
	ldi 	RMP, 	PORTB_IO
	out 	DDRB, 	RMP
	ldi 	RMP, 	PORTB_CFG
	out 	PORTB, 	RMP
; Init Portu C
	ldi 	RMP,	PORTC_IO
	out 	DDRC, 	RMP
	ldi 	RMP, 	PORTC_CFG
	out 	PORTC, 	RMP
; Init Portu D
	ldi 	RMP, 	PORTD_IO
	out 	DDRD, 	RMP
	ldi 	RMP, 	PORTD_CFG
	out 	PORTD, 	RMP
; wylaczenie komparatora analogowego
	ldi	RMP,	(1 << ACD)
	out	ACSR,	RMP
; Init uzywanych zmiennych
	ldi	RMP,	(1 << C_PIN)
	mov	C_EOR,	RMP
	ldi 	TICKS, 	0b00000000
	ldi 	TIME_S, 0b00000000
	ldi	TIME_M,	0b00000000
	ldi	TIME_H,	0b00000000
	ldi	FLAGS,	0b00000001
; Init zegara
	ldi 	RMP, 	0b00000001
	out 	TCCR0, 	RMP
	ldi 	RMP, 	0b00000001				
	out 	TIMSK, 	RMP
; Umozliwienie usypiania ukladu
	ldi 	RMP, 	(1 << SE) 
	out 	MCUCR, 	RMP
; Wypelnienie rejestrow tymczasowych (porty) MAKRO!!!!!!
	ldi	RMP,	PORTA_MASK
	mov 	AMASK, 	RMP
	ldi	RMP,	PORTB_MASK
	mov 	BMASK, 	RMP
	ldi	RMP,	PORTC_MASK
	mov 	CMASK, 	RMP
	ldi	RMP,	PORTD_MASK
	mov 	DMASK, 	RMP
; zero tylko na miejscu CLK i pinow zwartych do masy
	ldi 	RMP, 	0b01111111 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!!
	mov 	TPORTA, RMP
	ldi 	RMP, 	0b01111010 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!!
	mov 	TPORTB, RMP
	ldi 	RMP, 	0b01111111 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!!
	mov 	TPORTC, RMP
	ldi 	RMP, 	0b01111111 ; POPRAWIC, JEST ZAKODOWANE NA STALE!!!
	mov 	TPORTD, RMP
; TODO: Wypelnienie ramu bajtami okreslajacymi konfiguracje
; portow mikrokontrolera dla konkretnych minut i godzin

; Zalaczenie przerwan, start programu
	sei
;
; ============================================
;         G L O W N A   P E T L A
; ============================================
;
LOOP:
; ****************
; glowna petla (liczac od nopa wlacznie)
; maksymalnie ~30 cykli + update digits
; ****************
	sleep 
	nop 
LOOP_BTN_HANDLE:
	in	RMP,	BTN_PIN
	andi	RMP,	((1 << BTN_M) | (1 << BTN_H))				
	cpi	RMP,	((1 << BTN_M) | (1 << BTN_H))
	breq	LOOP_RELEASE_BTN_LOCK
	andi	FLAGS,	(1 << BTN_LOCK)
	brne	LOOP_DISPLAY_HANDLE
LOOP_BTN_PRESSED:
	sbr	FLAGS,	(1 << BTN_LOCK)
	sbrs	RMP,	BTN_M
	inc	TIME_M
	sbrs	RMP,	BTN_H
	inc	TIME_H
	sbr	FLAGS,	(1 << UPDATE_REQ)
	rjmp	LOOP_MOVERFLOW
LOOP_RELEASE_BTN_LOCK:
	cbr	FLAGS,	(1 << BTN_LOCK)
LOOP_MOVERFLOW:
	cpi	TIME_M,	60
	brlo	LOOP_HOVERFLOW
	ldi	TIME_M,	0b00000000
LOOP_HOVERFLOW:
	cpi	TIME_H,	24
	brlo	LOOP_DISPLAY_HANDLE
	ldi	TIME_H,	0b00000000
LOOP_DISPLAY_HANDLE:
	sbrc	FLAGS,	UPDATE_REQ
	rcall	UPDATE_DIGITS
	rjmp 	LOOP 
;
; ============================================
;         P R O C E D U R Y
; ============================================
;
UPDATE_DIGITS:
; ****************
; wczytanie z tablic stanu portow dla danej cyfry,
; synchronizacja z obecnym stanem linii CLK 
; oraz wrzucenie tego do rejestrow tymczasowych
; ****************
; maksymalnie ~55 cykli wlacznie z ret
; ****************
	cbr	FLAGS,	(1 << UPDATE_REQ)
;	wypelnienie bajtu zerami, potrzebne przy inkrementacjach adresu
	ldi	RMP2,	0b00000000
;	wczytywanie bajtow definiujacych cyfry do rejestrow tymczasowych
;	najpierw minuty
	ldi	ZH,	HIGH(m_C * 2)
	ldi	ZL, 	LOW(m_C * 2)
	add	ZL,	TIME_M
	adc	ZH,	RMP2
	lpm
	mov	TPORTC,	R0
;
	ldi	ZH,	HIGH(m_A * 2)
	ldi	ZL, 	LOW(m_A * 2)
	add	ZL,	TIME_M
	adc	ZH,	RMP2
	lpm
	mov	TPORTA,	R0
; potem godziny
	ldi	ZH,	HIGH(h_D * 2)
	ldi	ZL, 	LOW(h_D * 2)
	add	ZL,	TIME_H
	adc	ZH,	RMP2
	lpm
	mov	TPORTD,	R0
;
	ldi	ZH,	HIGH(h_B * 2)
	ldi	ZL, 	LOW(h_B * 2)
	add	ZL,	TIME_H
	adc	ZH,	RMP2
	lpm
	mov	TPORTB,	R0
; synchronizacja ze stanem CLK
	sbis	CK_PORT,CK_PIN
	rjmp	UPDATE_DIGITS_COLON
; synchronizacja ze stanem CLK
	eor	TPORTD, DMASK
	eor	TPORTC, CMASK
	eor	TPORTB, BMASK
	eor	TPORTA, AMASK
; przywrocenie stanu dwukropka
UPDATE_DIGITS_COLON:
	sbrc	TIME_S,	0
	rjmp	UPDATE_DIGITS_END
	sbrc	TPORTB,	CK_PIN ; MAKRO!!!!!!!!!!
	rjmp	UPDATE_DIGITS_END
	or	TPORTB,	C_EOR ; MAKRO!!!!!!!!!!
UPDATE_DIGITS_END:
; przywrocenie stanu klawiszy
	ldi	RMP,	PORTB_CFG
	or	TPORTB,	RMP
	ret
; ****************
;
; EOF main.asm
;
