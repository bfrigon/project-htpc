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

udelay  MACRO time

if (time <= 1275)
        movlw   time / 5
        call    delay10tcy
endif
        

        ENDM
        
        
        
        
        
        
mdelay  MACRO time

if (time <= 127)
        movlw   time * 2
        call    delay1ktcy
endif


        ENDM
        
        
        
        
sdelay  MACRO time


        ENDM
