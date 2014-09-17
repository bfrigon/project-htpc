;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     i2c.asm                                                    *
;*   Description:  I2C module                                                 *
;*   Last mod:     30 Dec. 2012                                               *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************
include <p18f2520.inc>
include "i2c.inc"        



;==============================================================================
;==============================================================================
;
;                                 Symbols 
;------------------------------------------------------------------------------
; *** subroutines ***
GLOBAL          i2c_init                    ; Initialize I2C module
GLOBAL          i2c_read
GLOBAL          i2c_write



;==============================================================================
;==============================================================================
;
;                                  Data
;------------------------------------------------------------------------------
; *** Access bank ***
.a_i2c          UDATA_ACS
i2c_addr        RES     0x01                ; Slave address

; *** RAM ***
;.b_i2c         UDATA
;rx_buffer      RES     0x100               ; Buffer



;==============================================================================
;==============================================================================
;
;                                Subroutines 
;------------------------------------------------------------------------------
.c_i2c          CODE
        


;******************************************************************************
; i2c_init : Initialize the I2C module
;
; Arguments : None
; Return    : None
;******************************************************************************
i2c_init:

#ifdef  DISABLE_I2C
        return
#endif

        bsf     LATC, LATC3
        bsf     LATC, LATC4
        bsf     TRISC, TRISC3
        bsf     TRISC, TRISC4

        movlw   0x08                        ; Set i2c master mode
        movwf   SSPCON1 
        
        movlw   0x13                        ; Set baud rate
        movwf   SSPADD                      ; (8mhz / (0x13+1)) = 100khz
        
        movlw   0x80
        movwf   SSPSTAT
        

        bsf     SSPCON1, SSPEN              ; Enable MSSP module
        return



;******************************************************************************
; i2c_write : Send data on i2c bus
;
; Arguments : W= Data to send
; Return    : None
;******************************************************************************
i2c_write:

#ifdef  DISABLE_I2C
        return
#endif
    
        bcf     PIR1, SSPIF                 ; Clear interrupt flag
        nop
        
        movwf   SSPBUF                      ; Set data in MSSP buffer
        btfss   PIR1, SSPIF                 ; Wait until MSSP finish ending
        goto    $-2

        btfsc   SSPCON2, ACKSTAT            ; Wait for ACK
        goto    $-2
        
        return


;******************************************************************************
; i2c_read
;
; Arguments : None
; Return    : Data
;******************************************************************************
i2c_read:

#ifdef  DISABLE_I2C
        retlw   0x00
#endif

        bcf     PIR1, SSPIF                 ; clear interrupt flag

        bsf     SSPCON2, RCEN               ; Enable receive mode
        btfss   PIR1, SSPIF                 ; Wait until data is received
        goto    $-2
        
        movf    SSPBUF, W
        bcf     SSPCON2, RCEN

        return


        
;==============================================================================
;==============================================================================
        END
        
