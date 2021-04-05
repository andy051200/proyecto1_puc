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
CONFIG  PWRTE=OFF           ; Power-up Timer prendido
CONFIG  MCLRE=OFF           ; MCLRE apagado
CONFIG  CP=OFF              ; Code Protection bit apagado
CONFIG  CPD=OFF             ; Data Code Protection bit apagado

CONFIG  BOREN=OFF           ; Brown Out Reset apagado
CONFIG  IESO=OFF            ; Internal External Switchover bit apagado
CONFIG  FCMEN=OFF           ; Fail-Safe Clock Monitor Enabled bit apagado
CONFIG  LVP=OFF	    ; low voltaje programming prendido

;----------configuration word 2-------------------------------------------------
CONFIG BOR4V=BOR40V	    ;configuraciÃ³n de brown out reset
CONFIG WRT = OFF	    ;apagado de auto escritura de cÃ?Â³digo
    
;---------------------macros---------------------------------------------------
;configuracion de macro para reinicio del timer0
reset_timer0	macro	    ; lo que anteriormente fue subrutina, se hizo macro
    banksel	PORTA	    ; por si las moscas ir a PortA
    movlw	250	    ; se carga valor inicial de 240, 0.02sec
    movwf	TMR0	    ; se guarda en timer0
    bcf		T0IF	    ; bajar bandera cuando no hay overflow
    endm       
    
;configuracion de macro para reinicio del timer1     
reset_timer1 macro
    banksel PORTA
    movlw   0xDC    ; el timmer contara a cada 0.25 segundos este en los LSB
    movwf   TMR1L   ; se carga 3036 que equivale a 0x0BDC
    movlw   0x0B    ; este se carga en los MSB
    movwf   TMR1H   ; registro al que se mueve
    bcf	    PIR1, 0 ; bajo la bandera
    endm   
    
;--------------------- variables ----------------------------------------------
PSECT udata_bank0
;variables para valores de contadores en semafores
    ;semaforo1
    total1:	DS 1
    verde1:	DS 1
    verdetit1:  DS 1
    amarillo1:	DS 1
    
    ;semaforo2
    total2:	DS 1
    verde2:	DS 1
    verdetit2:  DS 1
    amarillo2:	DS 1
    
    ;semaforo3
    total3:	DS 1
    verde3:	DS 1
    verdetit3:  DS 1
    amarillo3:	DS 1
    
    ;variables para multiplexada de displays
    muxeo:	    DS 1 ; para encender los displays
    display_var:    DS 8 ;tiene el valor de los displays, 8bytes
    dis_gris:	    DS 1
    tiempo_display1:	DS 1 
    tiempo_display2:	DS 1
    tiempo_display3:	DS 1
    
;variables para seleccion de semaforo activo
    modos:	DS 1
    sem_activo:	DS 2
    decenas:	DS 1
    residuo:	DS 1
    dividendo:	DS 1
    resta_o_no:	DS 1
    temporal1:	DS 1
    temporal2:	DS 1
    temporal3:	DS 1
    temporal:	DS 1
    
;variable contadora del timer1
    veces:	DS 1
    cont:	DS 1
    titileo:	DS 1

;---------------------- variables de interrupcion -----------------------------
PSECT udata_shr	    
    W_TEMP:	    DS 1
    STATUS_TEMP:    DS 1 
    tedejo:	    DS 1
    
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
    btfsc	RBIF
    call	in_on_change
    
    btfsc	TMR1IF
    call	suma_timer1
    
    btfsc	T0IF
    ;reset_timer0
    call	multiplexada
    
    
pop:
    swapf	STATUS_TEMP,W
    movwf	STATUS
    swapf	W_TEMP, F
    swapf	W_TEMP, W
    retfie            
;-------------------------- subrutinas de interruption -----------------------
in_on_change:
    banksel PORTB
    btfsc   PORTB,3
    goto    $+7
    incf    modos
    andlw   00000011B
       
    movlw   5
    subwf   modos,W
    btfsc   ZERO
    clrf    modos
   
    
    
    btfss   PORTB, 4  ;suma
    incf    temporal
    movlw   21
    subwf   temporal, W
    btfss   ZERO
    goto    $+3
    movlw   10
    movwf   temporal
    
    btfss   PORTB, 5  ;resta
    decf    temporal
    movlw   9
    subwf   temporal, W
    btfss   ZERO
    goto    ya
    movlw   20
    movwf   temporal
    
 ya:
    bcf	    RBIF
    return

suma_timer1: 
    reset_timer1
    incf    cont	;un pequeño delay para que la cuenta esté en sec
    movwf   cont, W	;
    sublw   4		;250ms * 4 = 1s
    btfss   ZERO	;
    goto    $+8
    clrf    cont	; ver si pasó el tiempo deseado
    incf    veces	;lleva la cuenta 
    
    btfsc   tedejo, 0
    goto    $+4
    decf    verde1
    btfsc   ZERO
    bsf	    tedejo, 0
 
    btfsc   tedejo, 1
    goto    $+4
    decf    verde2
    btfsc   ZERO
    bsf	    tedejo, 1
 
    btfsc   tedejo, 2
    goto    $+4
    decf    verde3
    btfsc   ZERO
    bsf	    tedejo, 2
 
    movlw 1
    xorwf	titileo, F
    return
 
multiplexada:
    reset_timer0
    movlw    0xff
    movwf   PORTD
    ;clrf    PORTD ; para apagar transistores durante interrupcion
    btfss   muxeo,0
    goto    display0
    btfss   muxeo,1
    goto    display1
    btfss   muxeo,2
    goto    display2
    btfss   muxeo,3
    goto    display3
    btfss   muxeo,4
    goto    display4
    btfss   muxeo,5
    goto    display5
    btfss   muxeo,6
    goto    display6
    btfss   muxeo,7
    goto    display7
    return
;display sem1
display0:
    bsf	    muxeo,0	    ;prendo el bit
    movf    display_var,W  ;mando su valor a variables a decenas dislay gris
    movwf   PORTC	    ;muevo su valor a port con displays
    bcf	    PORTD,3	    ;prendo el transistor correspondiente
    return

display1:
    bsf	    muxeo,1	    ;prendo el bit
    movf    display_var+1,W  ;mando valor a variables a unidades display gris
    movwf   PORTC	    
    bcf	    PORTD,2
    return
;display sem2
display2:
    bsf	    muxeo,2		;prendo el bit
    movf    display_var+2,W	;mando su valor a variables a unidades sem1
    movwf   PORTC	    
    bcf	    PORTD,5
    return

display3:
    bsf	    muxeo,3		;prendo el bit
    movf    display_var+3,W	;mando su valor a variables a unidades sem1
    movwf   PORTC	    
    bcf	    PORTD,4
    return
;display sem3
display4:
    bsf	    muxeo,4		;prendo el bit
    movf    display_var+4,W	;mando su valor a variables a unidades sem1
    movwf   PORTC	    
    bcf	    PORTD,7
    return

display5:
    bsf	    muxeo,5
    movf    display_var+5,W	;mando su valor a variables a unidades sem1
    movwf   PORTC	    
    bcf	    PORTD,6
    return
;display gris    
display6:
    bsf	    muxeo,6
    movf    display_var+6,W	;mando a variables a unidades displaygris
    movwf   PORTC	    
    bcf	    PORTD,1
    return
    
display7:
    bsf	    muxeo,7
    movf    display_var+7,W ;mando su valor a variables a unidades sem1
    movwf   PORTC	    
    bcf	    PORTD,0	    ;set bit de decenas
    clrf    muxeo	    ; para que vuelva a comenzar en 0
    return
    
;----------------------------- codigo principal -------------------------------
PSECT code, delta=2, abs
ORG 100h
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH = 01
    ;andwf   00001111B
    addwf   PCL		;PC = PCL + PCLATH + w
    retlw   11000000B ;0
    retlw   11111001B ;1
    retlw   10100100B ;2
    retlw   10110000B ;3
    retlw   10011001B ;4
    retlw   10010010B ;5
    retlw   10000010B ;6
    retlw   11111000B ;7
    retlw   10000000B ;8
    retlw   10010000B ;9
            
;--------------------------configuraciones ------------------------------------
main:    
    banksel	ANSEL	
    clrf	ANSEL	
    clrf	ANSELH
    
    banksel	TRISA
    clrf	TRISA	; PortA como salida, semaforo 1 y 2
    clrf	TRISC	; PortC como salida
    clrf	TRISD	; PortD como salida
    clrf	TRISE	; PortE como salida
    ; en PortB es así de detallado por ser el unica in/out port
    bcf		TRISB,0 ; se limpia para salida sem
    bcf		TRISB,1	; se limpia para salida sem
    bcf		TRISB,2 ; se limpia para salida sem
    ;botones de entrada de botones de cambio de semaforos
    bsf		TRISB,3 ;boton 1
    bsf		TRISB,4 ;boton 2
    bsf		TRISB,5 ;boton 3
    
    bcf		OPTION_REG,7
    bsf		WPUB,3	;weak pull up para boton 1
    bsf		WPUB,4	;weak pull up para boton 2
    bsf		WPUB,5	;weak pull up para boton 3
    ;configuracion de reloj
    call	reloj_config
    call	timer0_config
    call	timer1_config
    call	in_on_changeB
    call	interruption_config
    call	cargar_variables
    

    clrf	PORTA
    clrf	PORTB
    clrf	PORTC	    ; PortC como salida
    clrf	PORTD	    ; PortD como salida
    clrf	PORTE	    ; PortE como salida para displays de modos
       
    clrf	modos	    ; asegurarse que comience en 0
    bcf		sem_activo,0  ; asegurarse que comience en 0
    bsf		sem_activo,1
    bsf		sem_activo,2
    bsf		sem_activo,3
    bsf		sem_activo,4
    bsf		sem_activo,5
    bsf		sem_activo,6
    bsf		sem_activo,7
    bsf		sem_activo+1,0
    clrf	titileo	    ; asegurarse que comience en 0
    ;clrf	resta_o_no ; asegurarse que comience en 0
    bcf		tedejo,0 ;
    bsf		tedejo,1
    bsf		tedejo,2
    movlw	15
    movwf	temporal
  
            
;------------------------ loop de programa ------------------------------------
loop:
;semaforo de funcionamiento normal    
    call	semaforo_normal	;funcionamiento normal
;valores de displays    
    movf	verde1,W
    movwf	tiempo_display1
    movf	tiempo_display1,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_sem1
    
    movf	verde2,W
    movwf	tiempo_display2
    movf	tiempo_display2,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_sem2
    
    movf	verde3,W
    movwf	tiempo_display3
    movf	tiempo_display3,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_sem3

    
;subrutinas para configuracion de los semaforos    
    movlw	1	    ;se asigna 1, para que se pueda compara
    subwf	modos,W	    ;
    btfsc	ZERO
    call	semaforo1
    
    movlw	2
    subwf	modos,W
    btfsc	ZERO
    call	semaforo2
    
    movlw	3
    subwf	modos,W
    btfsc	ZERO
    call	semaforo3
    
    movlw	4
    subwf	modos,W
    btfsc	ZERO
    call   	aceptar_cancelar
    goto	loop
    
;------------------ subrutinas de loop --------------------------------
;--------- subrutinas de funcionamiento de semaforos
semaforo_normal:	;prender y apagar luces normales
       
    btfss   sem_activo,0
    call    sem_verde1
    btfss   sem_activo,1
    call    sem_verdetit1
    btfss   sem_activo,2
    call    sem_amarillo1
    
    btfss   sem_activo,3
    call    sem_verde2
    btfss   sem_activo,4
    call    sem_verdetit2
    btfss   sem_activo,5
    call    sem_amarillo2
    
    btfss   sem_activo,6
    call    sem_verde3
    btfss   sem_activo,7
    call    sem_verdetit3
    btfss   sem_activo+1,0
    call    sem_amarillo3
    return   
        
sem_verde1: ;semaforo 1 en verde normal
    bcf	    PORTA,0 ; led roja sem1, off
    bcf	    PORTA,1 ; led amarillo sem1 off
    bsf	    PORTA,2 ;led verde semaforo 1, on
    
    bsf	    PORTA,3 ;led roja semaforo 2 on
    bcf	    PORTA,4 ;led amarillo sem2 off
    bcf	    PORTA,5 ;led verde sem2 off
    
    bsf	    PORTB,0 ;led roja semaforo 3
    bcf	    PORTB,1 ;led amarillo sem3 off
    bcf	    PORTB,2 ;led verde sem3 off
       
    movwf   veces, W
    subwf   verde1, W
    btfss   ZERO
    goto    $+4
       
    bsf	    sem_activo,0
    bcf	    sem_activo,1
    clrf    veces
    return
;
sem_verdetit1: ;semaforo 1 en verde titilante
    btfss   titileo,0
    bsf	    PORTA,2
    btfsc   titileo,0
    bcf	    PORTA,2
    
    movwf   veces, W
    subwf   verdetit1, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,1
    bcf	    sem_activo,2
    clrf    veces
    return

sem_amarillo1:
    bcf	    PORTA,2
    btfss   titileo,0
    bsf	    PORTA,1
    btfsc   titileo,0
    bsf	    PORTA,1
    btfss   titileo,0
    bcf	    PORTA,1    
    
    movwf   veces, W
    subwf   amarillo1, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,2
    bcf	    sem_activo,3
    clrf    veces
    bsf	    tedejo,0
;    bcf	    tedejo,1
    return
 
sem_verde2:
    bcf	    tedejo,1
    
    bsf	    PORTA,0 ;led roja semaforo1, on
    bcf	    PORTA,1  ;led amarilla semaforo1 off
    bcf	    PORTA,2  ;led verde semaforo1 off
    
    bcf	    PORTA,3 ;led roja semaforo 2, off
    bcf	    PORTA,4 ;led amarilla semaforo2, off
    bsf	    PORTA,5 ;led verde semaforo2
    
    bsf	    PORTB,0 ;led roja semaforo3, on
    bsf	    PORTB,0 ;led amarilla semaforo3, off
    bsf	    PORTB,0 ;led verde semaforo 3, off
    
    movwf   veces, W
    subwf   verde2, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,3
    bcf	    sem_activo,4
    clrf    veces
    return
    
sem_verdetit2:
    btfss   titileo,0
    bcf	    PORTA,5
    btfsc   titileo,0
    bsf	    PORTA,5
    
    movwf   veces, W
    subwf   verdetit2, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,4
    bcf	    sem_activo,5
    clrf    veces
    return
    
sem_amarillo2:
    bcf	    PORTA,5
    btfss   titileo,0
    bcf	    PORTA,4
    btfsc   titileo,0
    bsf	    PORTA,4
    
    movwf   veces, W
    subwf   amarillo2, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,5
    bcf	    sem_activo,6
    clrf    veces
    bsf	    tedejo,1
    ;bcf	    tedejo,2
    return

sem_verde3:
    bcf	    tedejo,2
    
    bsf	    PORTA,0 ;led roja sem1, on
    bcf	    PORTA,1 ;led amarilla sem1, off
    bcf	    PORTA,2 ;led verde sem1, off
    
    bsf	    PORTA,3 ;led roja sem2,on
    bcf	    PORTA,4 ;led amarilla sem2,off
    bcf	    PORTA,5 ;led verde sem2, off
    
    bcf	    PORTB,0 ;led roja sem3, off
    bcf	    PORTB,1 ;led amarilla sem3, off
    bsf	    PORTB,2 ;led verde sem3, on
    
    movwf   veces, W
    subwf   verde3, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,6
    bcf	    sem_activo,7
    clrf    veces
    return
    
sem_verdetit3:
    btfss   titileo,0
    bcf	    PORTB,2
    btfsc   titileo,0
    bsf	    PORTB,2
    
    movwf   veces, W
    subwf   verdetit3, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo,7
    bcf	    sem_activo+1,0
    clrf    veces
    return
    
sem_amarillo3:
    bcf	    PORTB, 2
    btfss   titileo,0
    bcf	    PORTB,1
    btfsc   titileo,0
    bsf	    PORTB,1
    
    movwf   veces, W
    subwf   amarillo3, W
    btfss   ZERO
    goto    $+4
    bsf	    sem_activo+1,0
    bcf	    sem_activo,0
    clrf    veces
    bsf	    tedejo,2
    bcf	    tedejo,0
    return
    
;-------subrutinas de configuracion de semaforos    
semaforo1: ;se configura el tiempo del semaforo 1
  
    bsf	    PORTE,0
    bcf	    PORTE,1
    bcf	    PORTE,2
    
    movf    temporal, W
    movwf   temporal1
   
    movf	temporal,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_config_semaforos
     
    return
    
semaforo2:  ;se configura el tiempo del semaforo 2
    bcf		PORTE,0	    ;valor en leds de semaforo en configuracio
    bsf		PORTE,1
    bcf		PORTE,2
   
    movf    temporal, W
    movwf   temporal2
   
    
    movf	temporal,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_config_semaforos
    
    return
    
semaforo3:  ;se configura el tiempo del semaforo 3
    bcf		PORTE,0
    bcf		PORTE,1		;valor en leds de semaforo en configuracio
    bsf		PORTE,2
    
    
    movf    temporal, W
    movwf   temporal3
    
    movf	temporal,W
    movwf	dividendo   
    call	separador_decenas
    call	mandar_display_config_semaforos
    
    return
 
aceptar_cancelar:
    bsf	    PORTE,0
    bsf	    PORTE,1
    bsf	    PORTE,2
    
    btfsc   PORTB,4
    goto    $+5
    movlw   0010010B ;s
    movwf   display_var+7
    movlw   1111001B ;1
    movwf   display_var+6
    call    aceptar_config
    
    btfsc   PORTB,5
    goto    $+5
    movlw   1001000B
    movwf   display_var+7
    movlw   1000000B
    movwf   display_var+6
    call    cancelar_config
    
    return

aceptar_config:
    movf    temporal1,W ;muevo el temporal a verde1 con su nuevo valor
    movwf   verde1
    movf    temporal2,W ;muevo el temporal a verde2 con su nuevo valor
    movwf   verde2
    movf    temporal3,W ;muevo el temporal a verde3 con su nuevo valor
    movwf   verde3
    reset_timer1	;reseteo para que comience en 0 otra vez
    clrf    PORTE
    clrf    display_var+7
    clrf    display_var+6
    return

cancelar_config:
    clrf    PORTE
    clrf    display_var+7
    clrf    display_var+6
    return
    
;------subrutinas de multiplexación---    
separador_decenas:
    clrf    decenas
    movlw   10
    subwf   dividendo, F
    btfsc   CARRY	;
    incf    decenas	; 
    btfsc   CARRY
    goto    $-5 
    movlw   10
    addwf   dividendo, F
    return
    
mandar_display_sem1:
    movf    decenas,W
    call    tabla
    movwf   display_var+1   ;manda valor a decenas de semaforo1
    
    movf   dividendo, W
    call    tabla
    movwf   display_var	    ;manda valor a unidades de semaforo1
    return
    
mandar_display_sem2:
    movf    decenas,W
    call    tabla
    movwf   display_var+3   ;manda valor a decenas de semaforo2
    
    movf   dividendo, W
    call    tabla
    movwf   display_var+2 ;manda valor a unidades de semaforo2
    return
    
mandar_display_sem3:
    movf    decenas,W
    call    tabla
    movwf   display_var+5   ;manda valor a decenas de semaforo3
    
    movf    dividendo, W
    call    tabla
    movwf   display_var+4 ;manda valor a unidades de semaforo3
    return
 
mandar_display_config_semaforos:
    movf    decenas,W
    call    tabla
    movwf   display_var+7
    
    movf    dividendo,W
    call    tabla
    movwf   display_var+6
       
    return   
    
;------------------ subrutinas de configuración --------------------------------
reloj_config:
    banksel	OSCCON
    bsf		IRCF2	; reloj a 1Mhz 100
    bcf		IRCF1	; reloj a 1Mhz 100
    bcf		IRCF0	; reloj a 1Mhz 100
    bsf		SCS	; reloj interno on
    return

timer0_config:    
    banksel	TRISA
    bcf		T0CS
    bcf		PSA	; preescaler 
    bsf		PS2	; preescaler 111
    bsf		PS1	; preescaler 111
    bsf		PS0	; preescaler 111
    reset_timer0
    return
    
timer1_config:
    banksel TRISA
    bsf	    PIE1,0	; se activa el tmr1
    
    banksel T1CON
    bsf	    T1CON,0	; se prende el timer1
    bcf	    T1CON,1	; se usa como temporizador
    bcf	    T1CON,2	; sincronizado
    bcf	    T1CON,3	; 
    bsf	    T1CON,4	; prescaler 11-> 1:8
    bsf	    T1CON,5	; prescaler 11-> 1:8
    reset_timer1
    return
    
in_on_changeB:
    ;banksel	TRISB
    banksel	IOCB	    
    bsf		IOCB,3	    ; interrupt on change PortB, 3 encendido
    bsf		IOCB,4	    ; interrupt on change PortB, 4 encendido
    bsf		IOCB,5	    ; interrupt on change PortB, 5 encendido
    banksel	PORTA
    movf	PORTB, W
    bcf		RBIF	    
    return       

interruption_config:
    bsf		GIE	; enable interrupciones globales
    bsf		T0IE	; Tmr0 Int enable, encendido
    bcf		T0IF	; se limpia Tmr0IF
    
    bsf		PIE1,0	    ; enable bit de interrupcion tmr1, encendido
    bcf		PIR1,0	    ; interrupcion tmr1, apagada   
    bsf		RBIE	    ; int on change portb enable bit, on
    bcf		RBIF
    return    

cargar_variables:
    ;cargar valores para semaforo 1
    banksel	PORTA
    movlw	8	    
    movwf	verde1,F    
    movwf	tiempo_display1,F 
    movwf	verde2,F	    
    movwf	tiempo_display2,F
    movwf	verde3,F	    
    movwf	tiempo_display3,F
        
    movlw	3
    movwf	verdetit1,F
    movwf	amarillo1,F
    movwf	verdetit2,F
    movwf	amarillo2,F
    movwf	verdetit3,F
    movwf	amarillo3,F
    

    return
    

END