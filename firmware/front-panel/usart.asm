;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     usart.asm                                                  *
;*   Description:  USART module                                               *
;*   Last mod:     28 July 2012                                               *
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
; *** subroutines ***
GLOBAL  usart_init                          ; Initialize USART module
GLOBAL  usart_isr                           ; ISR routine
GLOBAL  usart_read_buffer                   ; Read next char from RX buffer
GLOBAL  usart_write_byte                    ; Send character




;==============================================================================
;==============================================================================
;
;                                    Data
;------------------------------------------------------------------------------
; *** Access bank ***
.a_usart        UDATA_ACS
w_ptr           RES     0x01                ; Buffer write ptr
r_ptr           RES     0x01                ; Buffer read ptr
rx_chr          RES     0x01                ; Character (temp)
prev_FSR2L      RES     0x01
prev_FSR2H      RES     0x01

; *** RAM ***
.b_usart        UDATA
rx_buffer       RES     0x100               ; Buffer



;==============================================================================
;==============================================================================
;
;                                Subroutines 
;------------------------------------------------------------------------------
.c_usart        CODE
        


;******************************************************************************
; usart_init : Initialize the USART module
;
; Arguments : None
; Return    : None
;******************************************************************************
usart_init:

        lfsr    FSR2, rx_buffer+0           ; 
        clrf    w_ptr
        clrf    r_ptr

        bcf     TRISC, TRISC6               ; Set TX pin as output
        bcf     LATC, LATC6
        bsf     TRISC, TRISC7               ; Set RX pin as input
        bcf     LATC, LATC7     

        clrf    BAUDCON                     ; TX idle high
        bsf     BAUDCON, BRG16              ; 16-bit baud rate generator

        movlw   D'12'                       ; 38400 bps 
        movwf   SPBRG                       ; 8Mhz/(16(12+1)) = 38461.538461538
        clrf    SPBRGH                      ; (+0.2% error)

        bsf     PIE1, RCIE                  ; Enable Receive interrupt

        clrf    TXSTA                       ; 8-bit, async mode, low speed
        bsf     TXSTA, TXEN                 ; Enable transmitter
        
        clrf    RCSTA                       ; 8-bit
        bsf     RCSTA, CREN                 ; Continous receive enabled
        bsf     RCSTA, SPEN                 ; Enable serial port

        return


;******************************************************************************
; usart_write_byte : Send character over USART
;
; Arguments : W= Character to write
; Return    : None
;******************************************************************************
usart_write_byte:
        btfss   PIR1, TXIF                  ; check if transmitter is busy
        bra     usart_write_byte
        
        movwf   TXREG                       ; Send the byte
        
        return        


;******************************************************************************
; usart_read_buffer : Read the next available character in the buffer
;
; Arguments : None
; Return    : W= Character read
;******************************************************************************
usart_read_buffer:
        movf    r_ptr,  W                   ; Block until a character is
        xorwf   w_ptr,  W                   ; available
        btfsc   STATUS, Z
        bra     usart_read_buffer

        movff   r_ptr, FSR2L                
        movf    INDF2, W                    ; Read the character from the 
                                            ; buffer
        incf    r_ptr                       ; Increment read pointer
        
        return
        

                


;******************************************************************************
; usart_isr : Interrupt service routine for USART receive 
;
; Arguments : None
; Return    : None
;******************************************************************************
usart_isr:
        movff   FSR2H, prev_FSR2H
        movff   FSR2L, prev_FSR2L

        btfsc   RCSTA, OERR
        bra     usart_isr_err_ovrr
        
        btfsc   RCSTA, FERR
        bra     usart_isr_err_frame
        
        incf    w_ptr, W                    ; Check if w_ptr+1 = r_ptr
        xorwf   r_ptr, W
        btfsc   STATUS, Z                   ; If so, the buffer is full
        bra     usart_isr_err_buf_full      ; ignore the character
        
        movff   w_ptr, FSR2L                ; Write character to buffer
        movff   RCREG, INDF2
        incf    w_ptr, F                    ; Increment write pointer

        bra     usart_isr_done
        
usart_isr_err_ovrr:
        bcf     RCSTA, CREN
        bsf     RCSTA, CREN
        bra     usart_isr_done

usart_isr_err_buf_full:        
usart_isr_err_frame:
        movf    RCREG, W
        bra     usart_isr_done
        
usart_isr_done:
        movff   prev_FSR2H, FSR2H
        movff   prev_FSR2L, FSR2L

        retfie  1
        
        
;==============================================================================
;==============================================================================
        END
        
