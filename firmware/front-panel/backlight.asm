;******************************************************************************
;*   Project:      PBX Front panel lcd                                        *
;*   Version:      0.1                                                        *
;*                                                                            *
;*   Filename:     backlight.asm                                              *
;*   Description:  LCD backlight control                                      *
;*   Last mod:     28 July 2012                                               *
;*                                                                            *
;*   Author:       Benoit Frigon                                              *
;*   Email:        <bfrigon@gmail.com>                                        *
;*                                                                            *
;******************************************************************************
include <p18f2520.inc>
include "macro.inc"
include "i2c.inc"
include "delay.inc"

I2CADDR_PCA9530_1		equ		0xC0		; PCA9530 #1 (Red)
I2CADDR_PCA9530_2		equ		0xC2		; PCA9530 #2 (Green, Blue)

REG_9530_INPUT			equ		0x00
REG_9530_PSC0			equ		0x01
REG_9530_PWM0			equ		0x02
REG_9530_PSC1			equ		0x03
REG_9530_PWM1			equ		0x04
REG_9530_LEDS			equ		0x05


DEF_BACKLIGHT_R			equ		d'140'
DEF_BACKLIGHT_G			equ		d'20'
DEF_BACKLIGHT_B			equ		d'0'



;==============================================================================
;==============================================================================
;
;                                 Symbols 
;------------------------------------------------------------------------------
; *** subroutines ***
GLOBAL			backlight_init				; Initialize backlight
GLOBAL			backlight_set				; Set backlight color
GLOBAL			backlight_get_clrtbl		; Set backlight with the color table



EXTERN			i2c_write

GLOBAL			colortbl
GLOBAL			backlight_lvl				; Current backlight color



;==============================================================================
;==============================================================================
;
;                                    Data
;------------------------------------------------------------------------------
; Access bank
.a_main			UDATA_ACS
backlight_lvl  	RES 	0x03				; Backlight levels (RGB)


.c_colortbl		CODE
colortbl
			;----- Normal intensity -----
			DB	d'0',d'0',d'0'				; Black
			DB	d'70',d'0',d'0'				; Red
			DB	d'0',d'50',d'0'				; Green
			DB	d'70',d'50',d'0'			; Yellow
			DB	d'0',d'0',d'50'				; Blue
			DB	d'70',d'0',d'50'			; Magenta
			DB	d'0',d'50',d'50'			; Cyan
			DB	d'70',d'50',d'50'			; White

			;----- High intensity -----
			DB	d'7',d'5',d'5'				; Black
			DB	d'255',d'0',d'0'			; Red
			DB	d'0',d'230',d'0'			; Green
			DB	d'255',d'200',d'0'			; Yellow
			DB	d'0',d'0',d'200'			; Blue
			DB	d'255',d'0',d'200'			; Magenta
			DB	d'0',d'200',d'200'			; Cyan
			DB	d'255',d'200',d'200'		; White



;==============================================================================
;==============================================================================
;
;                                Subroutines 
;------------------------------------------------------------------------------
.c_bklght		CODE



;******************************************************************************
; backlight_init : Initialize the two PCA9530 that control the LCD backlight
;
; Arguments : None
; Return	: None
;******************************************************************************
backlight_init:

		movlw	DEF_BACKLIGHT_R
		movwf	backlight_lvl+0
		movlw	DEF_BACKLIGHT_G
		movwf	backlight_lvl+1
		movlw	DEF_BACKLIGHT_B
		movwf	backlight_lvl+2

		;--------------------------------
		; Init first PCA9530 (Red)
		;--------------------------------			
		i2sb	SEN							; Start condition
		
		i2wr	I2CADDR_PCA9530_1			; Send slave address
		i2wr	REG_9530_PSC0 + 0x10		; First register + auto increment

		i2wr	0x00						; PSC0 = 0, maximum frequency
		i2wr	DEF_BACKLIGHT_R				; PWM0 = x, Red duty cycle

		i2wr	0x00						; PSC1 = 0, not used
		i2wr	0x00						; PWM1 = 0, not used

		i2wr	0x02						; LED0 = PWM0, LED1 = OFF
		
		i2sb	PEN							; Stop condition

		
		;--------------------------------
		; Init second PCA9530 (Green, blue)
		;--------------------------------	
		i2sb	SEN							; Start condition
		
		i2wr	I2CADDR_PCA9530_2			; Select second PCA9530
		i2wr	REG_9530_PSC0 + 0x10		; Select PSC0 register
											; and set auto-increment
		
		i2wr	0x00						; PSC0 = 0, maximum frequency
		i2wr	DEF_BACKLIGHT_G				; PWM0 = x, Green duty cycle

		i2wr	0x00						; PSC1 = 0, maximum frequency
		i2wr	DEF_BACKLIGHT_B				; PWM1 = x, Blue duty cycle

		i2wr	0x0B						; LED0 = PWM0, LED1 = PWM1

		i2sb	PEN							; Stop condition

		return



;******************************************************************************
; backlight_set : Set the pwm on each PCA9530 to the value stored in
;                 backlight_lvl+0 (red), +1 (green) and +2 (blue)
;
; Arguments : None
; Return	: None
;******************************************************************************
backlight_set:

		;--------------------------------
		; Set first PCA9530 pwm (Red)
		;--------------------------------
		i2sb	SEN							; Start condition
		
		i2wr	I2CADDR_PCA9530_1			; Send slave address
		i2wr	REG_9530_PWM0				; Select PWM0 register
		
		movf	backlight_lvl+0, W
		call	i2c_write
		
		i2sb	SEN							; Stop condition
		

		;--------------------------------
		; Set second PCA9530 pwm (Green)
		;--------------------------------
		i2sb	SEN							; Start condition
		
		i2wr	I2CADDR_PCA9530_2			; Send slave address
		i2wr	REG_9530_PWM0				; Select PWM0 register
		
		movf	backlight_lvl+1, W
		call	i2c_write
		
		i2sb	SEN							; Stop condition


		;--------------------------------
		; Set second PCA9530 pwm (Blue)
		;--------------------------------
		i2sb	SEN							; Start condition
		
		i2wr	I2CADDR_PCA9530_2			; Send slave address
		i2wr	REG_9530_PWM1				; Select PWM1 register
		
		movf	backlight_lvl+2, W
		call	i2c_write
		
		i2sb	SEN							; Stop condition
		

		return



;******************************************************************************
; backlight_get_clrtbl : Read RGB value from the color table. 
;
; Arguments : W=Color id (0-15)
; Return	: None
;******************************************************************************
backlight_get_clrtbl:

		mullw	4							; Multiply W by 4

		ltblptr	colortbl					; Set table ptr to start of colortbl

		addff16	PRODL,PRODH,TBLPTRL,TBLPTRH	; Offset table ptr by the result
											; of the multiplication
		
		
		clrf	EECON1
		bsf		EECON1,	EEPGD
		
		tblrd*+
		movff	TABLAT, backlight_lvl+0
		tblrd*+
		movff	TABLAT, backlight_lvl+1
		tblrd*+
		movff	TABLAT, backlight_lvl+2

		call	backlight_set
		
		return

		
;==============================================================================
;==============================================================================
		END		
