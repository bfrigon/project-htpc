;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     delay.asm                                                  *
;*   Description:  Delay subroutines                                          *
;*   Last mod:     11 august 2012                                             *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************
include <p18f2520.inc>



;==============================================================================
;==============================================================================
;
;                                   Symbols 
;------------------------------------------------------------------------------
; *** Subroutines ***
GLOBAL	delay10tcy
GLOBAL  delay100tcy
GLOBAL  delay1ktcy
GLOBAL	delay10ktcy
GLOBAL  delay200ktcy


;==============================================================================
;==============================================================================
;
;                                     Data   
;------------------------------------------------------------------------------
; Access bank
.a_delay		UDATA_ACS
d1            	RES		0x01				; Delay counters
d2            	RES		0x01				; 
d3            	RES		0x01				;  
d4              RES     0x01                ;  


;==============================================================================
;==============================================================================
;
;                                Subroutines 
;------------------------------------------------------------------------------		
.c_delay		CODE


;******************************************************************************
; delay10tcy : delay 10 cycles (5us @ 8Mhz)
;
; Arguments : W= cycles count (W x 10 cycles)
; Return	: None
;******************************************************************************
delay10tcy:
        movwf   d1
        decf    d1, F
        bnz     loop_delay10tcy
        bra     $+2
        return
        
loop_delay10tcy:
        bra     $+2
        bra     $+2
        bra     $+2
        nop
        decfsz  d1, F                 
        bra     loop_delay10tcy        
        bra     $+2
        return


;******************************************************************************
; delay100tcy : delay 100 cycles (50us @ 8Mhz)
;
; Arguments : W= cycles count (W x 100 cycles)
; Return	: None
;******************************************************************************
delay100tcy:
        movwf   d2
        
loop_delay100tcy:
        movlw   D'9'
        rcall   delay10tcy
        
        decf    d2, F
        nop
        bz      delay100tcy_done
        
        bra $+2
        bra $+2
        nop
        
        bra     loop_delay100tcy

delay100tcy_done:
        return


;******************************************************************************
; delay1ktcy : delay 1000 cycles (0.5ms @ 8Mhz)
;
; Arguments : W= cycles count (W x 1000 cycles)
; Return	: None
;******************************************************************************
delay1ktcy:
        movwf   d2
        
loop_delay1ktcy:
        movlw   D'99'
        rcall   delay10tcy
        
        decf    d2, F
        nop
        bz      delay1ktcy_done
        
        bra $+2
        bra $+2
        nop
        
        bra     loop_delay1ktcy

delay1ktcy_done:
        return        


;******************************************************************************
; delay10ktcy : delay 10000 cycles (5ms @ 8Mhz)
;
; Arguments : W= cycles count (W x 10000 cycles)
; Return	: None
;******************************************************************************
delay10ktcy:
        movwf   d3

loop_delay10ktcy:        
        movlw   D'10'
        rcall   delay1ktcy
        
        decfsz  d3, F
        bra     loop_delay10ktcy
        
        return

        
;******************************************************************************
; delay200ktcy : delay 100000 cycles (100ms @ 8Mhz)
;
; Arguments : W= cycles count (W x 200000 cycles)
; Return    : None
;******************************************************************************
delay200ktcy:        
        movwf   d4

loop_delay200ktcy:        
        movlw   D'20'
        rcall   delay10ktcy
        
        decfsz  d4, F
        bra     loop_delay200ktcy
        
        return




;==============================================================================
;==============================================================================
        END
