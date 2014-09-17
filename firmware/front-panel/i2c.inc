;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     i2c.inc                                                    *
;*   Description:  I2C macro                                                  *
;*   Last mod:     30 dec. 2012                                               *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************

;#define DISABLE_I2C


i2wr    MACRO   data
#ifdef  DISABLE_I2C
        nop
#else
        movlw   data
        call    i2c_write
#endif
        ENDM


i2rd    MACRO   reg
#ifdef  DISABLE_I2C
        nop
#else
        call    i2c_read
        movwf   reg
#endif
        ENDM


i2sb    MACRO   bit
#ifdef  DISABLE_I2C
        nop
#else
        bsf     SSPCON2, bit                ; Set condition
        btfsc   SSPCON2, bit                ; Wait until MSSP finish
        goto    $-2
#endif
        ENDM
        
        
i2ack   MACRO
#ifdef  DISABLE_I2C
        nop
#else
        bcf     SSPCON2, ACKDT              ; ACK
        bsf     SSPCON2, ACKEN              ; Send ACK
        btfsc   SSPCON2, ACKEN              ; Wait until ACK has ben sent
        goto    $-2
#endif
        ENDM
        
i2nck   MACRO
#ifdef  DISABLE_I2C
        nop
#else
        bsf     SSPCON2, ACKDT              ; No-ACK
        bsf     SSPCON2, ACKEN              ; Send ACK
        btfsc   SSPCON2, ACKEN              ; Wait until ACK has ben sent
        goto    $-2     
#endif
        ENDM
