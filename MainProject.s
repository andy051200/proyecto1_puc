;------------------------------------------------------------------------------
;Archivo: mainsproject.s
;Microcontrolador: PIC16F887
;Autor: Andy Bonilla
;Compilador: pic-as (v2.30), MPLABX v5.45
    
;Programa: Proyecto1
;Hardware: PIC16F887
    
;Creado: 10 de marzo de 2021    
;Descripcion: Semaforo de 3 vias, con botones de cambio de modo, asi como 
; botones para incrementar o decrementar el tiempo de cuenta
;------------------------------------------------------------------------------

;---------libreras a emplementar-----------------------------------------------
PROCESSOR 16F887
#include <xc.inc>
;------configuration word 1----------------------------------------------------
CONFIG  FOSC=INTRC_NOCLKOUT ;se declara osc interno
CONFIG  WDTE=OFF            ; Watchdog Timer apagado
CONFIG  PWRTE=ON            ; Power-up Timer prendido
CONFIG  MCLRE=OFF           ; MCLRE apagado
CONFIG  CP=OFF              ; Code Protection bit apagado
CONFIG  CPD=OFF             ; Data Code Protection bit apagado

CONFIG  BOREN=OFF           ; Brown Out Reset apagado
CONFIG  IESO=OFF            ; Internal External Switchover bit apagado
CONFIG  FCMEN=OFF           ; Fail-Safe Clock Monitor Enabled bit apagado
CONFIG  LVP=ON		    ; low voltaje programming prendido

;----------configuration word 2-------------------------------------------------
CONFIG BOR4V=BOR40V	    ;configuraciÃ³n de brown out reset
CONFIG WRT = OFF	    ;apagado de auto escritura de cÃ?Â³digo
    
;---------------------macros---------------------------------------------------
;configuracion de macro para reinicio del timer0
reset_timer0	macro	    ; lo que anteriormente fue subrutina, se hizo macro
    movlw	40	    ; dada la configuración del prescaler
    movwf	TMR0	    ; se guarda en timer0
    bcf		T0IF	    ; bandera cuando no hay overflow
    endm       
    
;configuracion de macro para reinicio del timer1     
reset_timer1 macro
    banksel PORTA
    movlw   0x40    ; el timmer contara a cada 0.50 segundos este en los LSB
    movwf   TMR1L   ; se carga 2880 que equivale a 0x0BDC
    movlw   0x0B    ; este se carga en los MSB
    movwf   TMR1H   ; registro al que se mueve
    bcf	    PIR1, 0 ;bajo la bandera
    endm   
    
;--------------------- variables ----------------------------------------------
PSECT udata_bank0
;variables para valores de contadores en semafores
    ;semaforo1
    verde1:	DS 2
    verdetit1:  DS 2
    amarillo1:	DS 2
    
    ;semaforo2
    verde2:	DS 2
    verdetit2:  DS 2
    amarillo2:	DS 2
    
    ;semaforo3
    verde3:	DS 2
    verdetit3:  DS 2
    amarillo3:	DS 2
 
;variables para seleccion de modos
    modos:
    modo1:	DS 1
    modo2:	DS 1
    modo3:	DS 1
    
;variable contadora del timer1
    vecestmr1:	DS 2
    cont:	DS 2

;---------------------- variables de interrupcion -----------------------------
PSECT udata_shr	    
    W_TEMP:	    DS 1
    STATUS_TEMP:    DS 1  
    cuenta:	    DS 1
    numero:	    DS 1
    aumento:	    DS 1
    
;--------------------------- reset vector -------------------------------------
PSECT resVect, class=CODE, abs, delta=2 ;
ORG 00h
resetVector:
    PAGESEL main
    goto main
    
;------------------------ interrupt vector ------------------------------------
PSECT	intVect, class=code, abs, delta=2 
ORG 04h
push:
    movwf	W_TEMP
    swapf	STATUS, W
    movwf	STATUS_TEMP	
isr:
    btfsc	PIR1,0	    ;ver si está 
    call	sem_verde1 ;interruption_tm1
    
    btfsc	RBIF
    call	select_semaforo
     
pop:
    swapf	STATUS_TEMP
    movwf	STATUS
    swapf	W_TEMP, F
    swapf	W_TEMP, W
    retfie            
;-------------------------- subrutinas de interruption -----------------------
;------------------- subrutinas de semaforos
;subrutinas de selección de modos de configuracion de semaforos

;if_semaforo:		    ;si desea modificar algun semaforo
;    bsf		PORTE,0	    ;se prenden leds para identificar que se entró
;    bsf		PORTE,1
;    bsf		PORTE,2
;    ;idealmente prender a lo loco el display gris    
;    
;    banksel	PORTB
;    btfsc	PORTB,3	    ;opcion si quiere aceptar configurar algun sem
;    ;incf	verde1
;    goto	select_semaforo ;manda a configuracion
;    
;    
;    btfsc	PORTB,5	  ;opcion si quiere cancelar configurar algun sem
;    clrf	PORTE	  ;apagar las leds del puerto
;    goto	
    
select_semaforo:
    clrf	PORTE	;por si las moscas un clrf en el portE
    btfsc	PORTB,3
    goto	$+3
    incf	modos	    ;esto me permite comparar el modo al que quiere ir
    incf	PORTE
    goto	comparador1
  
    
comparador1:
    movf	modo1,W 		; mover contador de bits a reg W
    subwf	PORTE,W		; restar variable contadora del PortB (auto leds)
    btfss	ZERO		; evaluar si bit zero = 0 para confirmar
    goto	comparador2	; si la resta =!0, se vuelve a comparar
    goto	config_sem1   
        
comparador2:
    movf	modo2,W 		; mover contador de bits a reg W
    subwf	PORTE,W		; restar variable contadora del PortB (auto leds)
    btfss	ZERO	; evaluar si bit zero = 0 para confirmar
    goto	comparador3
    goto	config_sem2	; si la resta=0, se configura semaforo 1
            
comparador3:
    movf	modo3,W 		; mover contador de bits a reg W
    subwf	PORTE,W		; restar variable contadora del PortB (auto leds)
    btfss	ZERO	; evaluar si bit zero = 0 para confirmar
    goto	pop
    goto	config_sem3	; si la resta=0, se configura semaforo 1  
    
config_sem1:
    bsf		PORTE,0	 ;se enciende led para indicar numero de modo, 1
        
    btfsc	PORTB,4	    ;aqui se está sumando si quiere
    goto	$+1	    ; manda a revisar en boton de resta
    incf	verde1	    ;suma en semaforo de interes
        
    btfsc	PORTB,2	    ;aqui está restando si quiere
    goto	$+1
    decf	verde1	    ;resta en semaforo de interes
        
    clrf	PORTE
    goto	select_aceptarono 
    
config_sem2:
    bsf		PORTE,0	;se enciende led para indicar numero de modo, 2
    bsf		PORTE,1 ;se enciende led para indicar numero de modo, 2
    
    btfsc	PORTB,4	    ;aqui se está sumando si quiere
    goto	$+1	    ; manda a revisar en boton de resta
    incf	verde2	    ;suma en semaforo de interes
    
    btfsc	PORTB,2	    ;aqui está restando si quiere
    goto	$+1
    decf	verde2	    ;resta en semaforo de interes
        
    clrf	PORTE
    goto	select_aceptarono
           
config_sem3:
    bsf		PORTE,0 ;se enciende led para indicar numero de modo, 3
    bsf		PORTE,1 ;se enciende led para indicar numero de modo, 3
    bsf		PORTE,2 ;se enciende led para indicar numero de modo, 3
    
    btfsc	PORTB,1	    ;aqui se está sumando si quiere
    goto	$+1	    ;manda a revisar en boton de resta
    incf	verde3	    ;suma en semaforo de interes
        
    btfsc	PORTB,2	    ;aqui está restando si quiere
    goto	$+1
    decf	verde3	    ;resta en semaforo de interes
    
    clrf	PORTE
    goto	select_aceptarono
    
select_aceptarono:
    btfsc	PORTB,1	    ;si desea aceptar los cambios se reinicia
    reset_timer1
    btfsc	PORTB,2	    ;si no desea aceptar los cambios, regresa
    return
    
;------------------- subrutinas de semaforos    
;subrutinas de semaforo1
sem_verde1:
    ;sem1 en verde normal
    bsf	    PORTA,2 ;led verde semaforo 1
    bsf	    PORTA,3 ;led roja semaforo 2
    bsf	    PORTB,0 ;led roja semaforo 3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verde1, W
    btfss   ZERO
    goto    sem_verde1
    
    call    delay_big
    bcf	    PORTA,2 ;led verde semaforo 1
    bcf	    PORTA,3 ;led roja semaforo 2
    bcf	    PORTB,0 ;led roja semaforo 3
    clrf    vecestmr1
    goto    sem_amarillo1 ;sem_verdetit1
    return

sem_verdetit1:
    bsf	    PORTA,2 ;hacer que titile led verde semaforo 1
    call    delay_small
    bcf	    PORTA,2
    call    delay_small
    bsf	    PORTA,2 ;hacer que titile led verde semaforo 1
      
    bsf	    PORTA,3 ;led roja semaforo2
    bsf	    PORTB,0 ;led roja semaforo3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verdetit1, W
    btfss   ZERO
    goto    sem_verdetit1
    
    call    delay_big
    clrf    vecestmr1
    goto    sem_amarillo1
    return
    
sem_amarillo1:
    bsf	    PORTA,1 ;led amarilla semaforo1
    call    delay_small
    bcf	    PORTA,1
    call    delay_small
    bsf	    PORTA,1 ;led amarilla semaforo1
    
    bsf	    PORTA,3 ;led roja semaforo2
    bsf	    PORTB,0 ;led roja semaforo3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   amarillo1, W
    btfss   ZERO
    goto    sem_amarillo1
    
    call    delay_big
    bcf	    PORTA,1 ;led amarilla semaforo1
    bcf	    PORTA,3 ;led roja semaforo2
    bcf	    PORTB,0 ;led roja semaforo3
    clrf    vecestmr1
    goto    sem_verde2 ;sem_verdetit1
    return
      
;subrutinas de semaforo2
sem_verde2:
    bsf	    PORTA,0 ;led roja semaforo1
    bsf	    PORTA,5 ;led verde semaforo2
    bsf	    PORTB,0 ;led roja semaforo3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verde2, W
    btfss   ZERO
    goto    sem_verde2
    
    call    delay_big
    bcf	    PORTA,0 ;led roja semaforo1
    bcf	    PORTA,5 ;led verde semaforo2
    bcf	    PORTB,0 ;led roja semaforo3
    clrf    vecestmr1
    goto    sem_verdetit2 ;sem_verdetit1
    return
    
sem_verdetit2:
    bsf	    PORTA,0 ;led roja semaforo1
    
    bsf	    PORTA,5 ;hacer que titile led verde semaforo2
    call    delay_small
    bcf	    PORTA,5
    call    delay_small
    bsf	    PORTA,5  
    
    bsf	    PORTB,0 ;led roja semaforo3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verdetit2, W
    btfss   ZERO
    goto    sem_verdetit2
    
    call    delay_big
    bcf	    PORTA,0 ;led roja semaforo1
    bcf	    PORTA,5 ;hacer que titile led verde semaforo2
    bcf	    PORTB,0 ;led roja semaforo3
    clrf    vecestmr1
    goto    sem_amarillo2
    return
    
sem_amarillo2:
    bsf	    PORTA,0 ;led roja sem1
    
    bsf	    PORTA,4 ;led amarilla semaforo 2
    call    delay_small
    bcf	    PORTA,4
    call    delay_small
    bsf	    PORTA,4
    
    bsf	    PORTB,0 ;led roja semaforo2
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   amarillo2, W
    btfss   ZERO
    goto    sem_amarillo2
    
    call    delay_big
    bcf	    PORTA,0 ;led roja sem1
    bcf	    PORTA,4 ;led amarilla semaforo 2
    bcf	    PORTB,0 ;led roja semaforo2
    clrf    vecestmr1
    goto    sem_verde3 ;sem_verdetit1
    return

;subrutinas de semaforo3
sem_verde3:
    bsf	    PORTA,0 ;led roja sem1
    bsf	    PORTA,3 ;led roja sem2
    bsf	    PORTB,2 ;led verde sem3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verde3, W
    btfss   ZERO
    goto    sem_verde3
    
    call    delay_big
    bcf	    PORTA,0 ;led roja sem1
    bcf	    PORTA,3 ;led roja sem2
    bcf	    PORTB,2 ;led verde sem3
    clrf    vecestmr1
    goto    sem_verdetit3
    return
    
sem_verdetit3:
    bsf	    PORTA,0 ;led roja sem1
    bsf	    PORTA,3 ;led roja sem2
    
    bsf	    PORTB,2 ;hacer que titile led verde semaforo3
    call    delay_small
    bcf	    PORTB,2
    call    delay_small
    bsf	    PORTB,2 ;hacer que titile led verde semaforo3
    
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   verdetit3, W
    btfss   ZERO
    goto    sem_verdetit3
    
    call    delay_big
    bcf	    PORTA,0 ;led roja sem1
    bcf	    PORTA,3 ;led roja sem2
    bcf	    PORTB,2 ;hacer que titile led verde semaforo3
    clrf    vecestmr1
    
    goto    sem_amarillo3
    return
    
sem_amarillo3:
    bsf	    PORTA,0 ;led roja sem1
    bsf	    PORTA,3 ;led roja sem2
    
    bsf	    PORTB,1 ;led amarilla sem3
    call    delay_small
    bcf	    PORTB,1
    call    delay_small
    bsf	    PORTB,1 ;led amarilla sem3
        
    incf    vecestmr1
    movwf   vecestmr1, W
    subwf   amarillo3, W
    btfss   ZERO
    goto    sem_amarillo3
    
    call    delay_big
    bcf	    PORTA,0 ;led roja sem1
    bcf	    PORTA,3 ;led roja sem2
    bcf	    PORTB,1 ;led amarilla sem3
    clrf    vecestmr1
    
    goto    sem_verde1
    return

;------------------- subrutinas de displays multiplexados

    
;----------------------------- codigo principal -------------------------------
PSECT code, delta=2, abs
ORG 100h
 
    
;--------------------------configuraciones ------------------------------------
main:    
    call    io_config
    call    reloj_config
    call    timer0_config
    call    timer1_config
    call    interruption_config
    call    cargarvariables
        
;------------------------ loop de programa ------------------------------------
loop:
    goto    loop
    
;------------------------ subrutinas regulares --------------------------------
cargarvariables:	;lo puse aquí por comodidad de referencia
;cargar valores para semaforo 1
    banksel	PORTA
    movlw	0x04	    
    movwf	verde1
    movlw	0x03
    movwf	verdetit1
    movlw	0x03
    movwf	amarillo1
    
;cargar valores para semaforo2
    movlw	0x04	    
    movwf	verde2
    movlw	0x03
    movwf	verdetit2
    movlw	0x03
    movwf	amarillo2
    
;cargar valores para semaforo2
    movlw	0x04	    
    movwf	verde3
    movlw	0x03
    movwf	verdetit3
    movlw	0x03
    movwf	amarillo3
    
;cargar valores para seleccion de modos
    movlw	0x01
    movwf	modo1
    movlw	0x02
    movwf	modo2
    movlw	0x03
    movwf	modo3
    return

io_config:
    banksel	ANSEL
    clrf	ANSEL
    clrf	ANSELH
    
    banksel	TRISA
    clrf	TRISA	; PortA como salida
    ; en PortB es así de detallado por ser el unica in/out port
    bcf		TRISB,0 ; se limpia para salida sem
    bcf		TRISB,1	; se limpia para salida sem
    bcf		TRISB,2 ; se limpia para salida sem
    bsf		TRISB,3	; set para entrada boton1
    bsf		TRISB,4 ; set para entrada boton2
    bsf		TRISB,5 ; set para entrada boton3
    clrf	TRISC	; PortC como salida
    clrf	TRISD	; PortD como salida
    clrf	TRISE	; PortE como salida
    
    banksel	PORTA
    clrf	PORTA
    ; en PortB es así de detallado por ser el unica in/out port
    bcf		PORTB, 0    ; salida de sem
    bcf		PORTB, 1    ; salida de sem
    bcf		PORTB, 2    ; salida de sem
    bsf		PORTB, 3    ; entrada boton1
    bsf		PORTB, 4    ; entrada boton2
    bsf		PORTB, 5    ; entrada boton3
    clrf	PORTC	    ; PortC como salida
    clrf	PORTD	    ; PortD como salida
    clrf	PORTE	    ; PortE como salida para displays de modos
    return  
    
reloj_config:
    banksel	OSCCON
    bcf		IRCF2
    bsf		IRCF1
    bcf		IRCF0
    bsf		SCS
    return

timer0_config:    
    banksel	TRISA
    bcf		T0CS
    bcf		PSA ; preescaler
    bsf		PS2
    bsf		PS1
    bsf		PS0
    banksel	PORTA
    movlw	125	; tiempo de demora de cambio en los display
    movwf	TMR0
    bcf		T0IF
    reset_timer0
    return
    
timer1_config:
    banksel TRISA
    bsf	    PIE1, 0	; se prende la interrupción del TMR1
    banksel T1CON
    bsf	    TMR1ON	;se prende el timer1
    bcf	    TMR1CS	; se activa el temporizador con intosc
    bcf	    T1SYNC	; sincronizacion apagada
    bsf	    T1CON, 3	; oscilador baja potencia
    bsf	    T1CON, 4	; prescaler 0, 11-> 1:8
    bsf	    T1CON, 5	; prescaler 1, 11-> 1:8
    bcf	    TMR1GE	; Gate enable apagado
    bcf	    T1GINV	;gate inverter apagado
    ;el valor a cargar en el timer es 3036
    movlw   0x7c	;se mueven MSB a TM1H
    movwf   TMR1H
    movlw   0xE1	;se mueven LSB a TMR1L
    movwf   TMR1L
    reset_timer1
    return

interruption_config:
    banksel	PORTA
    banksel	INTCON
    bsf		INTCON,7 ; interrupciones globales, encendido
    bsf		INTCON,6 ; interrupcion de perifericos, encendido
    bsf		INTCON,5 ; interrupcion Timer0, encendido
    bcf		INTCON,4 ; interrupcion externa enable, apagado
    bsf		INTCON,3 ; interreption on chance PortB enable bit, encendido
    bsf		INTCON,2 ; interrupcion Timer0, encendido
    bcf		INTCON,1 ; interrupcion externa, apagado
    bsf		INTCON,0 ; interruption on change PortB, encendida
    ;interrupciones del timer1 y timer2
    banksel	PIE1	 
    bsf		PIE1,0	    ; enable bit de interrupcion tmr1, encendido
    ;el resto van apagados
    
    banksel	PIR1
    bsf		PIR1,0	    ; interrupcion tmr1, encendida
    ;el resto van apagados
    banksel	IOCB	    
    bsf		IOCB,3	    ; interrupt on change PortB, 3 encendido
    bsf		IOCB,4	    ; interrupt on change PortB, 4 encendido
    bsf		IOCB,5	    ; interrupt on change PortB, 5 encendido
    banksel	PORTA
    movf	PORTB, W
    bsf		RBIF
    return       
    
delay_big:
    movlw   255
    movwf   cont+1
    call    delay_small
    decfsz  cont+1,f
    goto    $-2
    return

delay_small:
    movlw	255	    
    movwf	cont
    decfsz	cont,f
    goto	$-1
    return
    
END